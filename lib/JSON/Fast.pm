use nqp;

unit module JSON::Fast;

sub str-escape(str $text is copy) {
    $text .= subst('\\', '\\\\', :g);
    for flat 0..8, 11, 12, 14..0x1f -> $ord {
        my str $chr = chr($ord);
        if $text.contains($chr) {
            $text .= subst($chr, '\\u' ~ $ord.fmt("%04x"), :g);
        }
    }
    return $text.subst("\n", '\\n',     :g)\
                .subst("\r\n", '\\r\\n',:g)\
                .subst("\r", '\\r',     :g)\
                .subst("\t", '\\t',     :g)\
                .subst('"',  '\\"',     :g);
}

sub to-json($obj is copy, Bool :$pretty = True, Int :$level = 0, Int :$spacing = 2) is export {
    return $obj ?? 'true' !! 'false' if $obj ~~ Bool;
    return $obj.Str if $obj ~~ Int|Rat;

    if $obj ~~ Num {
        if $obj === NaN || $obj === -Inf || $obj === Inf {
            if try $*JSON_NAN_INF_SUPPORT {
                return $obj.Str;
            } else {
                return "null";
            }
        } else {
            return $obj.Str;
        }
    }

    return 'null' if not $obj.defined;
    return "\"{str-escape($obj)}\"" if $obj ~~ Str;

    if $obj ~~ Seq {
        $obj = $obj.cache
    }

    my int  $lvl  = $level;
    my Bool $arr  = $obj ~~ Positional;
    my str  $out ~= $arr ?? '[' !! '{';
    my $spacer   := sub {
        $out ~= "\n" ~ (' ' x $lvl*$spacing) if $pretty;
    };

    $lvl++;
    $spacer();
    if $arr {
        for @($obj) -> $i {
          $out ~= to-json($i, :level($level+1), :$spacing, :$pretty) ~ ',';
          $spacer();
        }
    }
    else {
        for $obj.keys -> $key {
            $out ~= "\"{$key ~~ Str ?? str-escape($key) !! $key}\": " ~ to-json($obj{$key}, :level($level+1), :$spacing, :$pretty) ~ ',';
            $spacer();
        }
    }
    $out .=subst(/',' \s* $/, '');
    $lvl--;
    $spacer();
    $out ~= $arr ?? ']' !! '}';
    return $out;
}

my sub nom-ws(str $text, int $pos is rw) {
    my int $wsord;
    nqp::handle(
        nqp::while(1,
            nqp::stmts(
                ($wsord = nqp::ordat($text, $pos)),
                (last unless $wsord == 32 || $wsord == 10 || $wsord == 13 || $wsord == 9),
                ($pos = $pos + 1)
            )),
            'CATCH',
            (die "reached end of string when looking for something"));
}

my sub tear-off-combiners(str $text, int $pos) {
    my str $combinerstuff = nqp::substr($text, $pos, 1);
    my Uni $parts = $combinerstuff.NFD;
    return $parts[1..*].map({$^ord.chr()}).join()
}

my Mu $hexdigits := nqp::hash(
    '97', 1, '98', 1, '99', 1, '100', 1, '101', 1, '102', 1,
    '48', 1, '49', 1, '50', 1, '51', 1, '52', 1, '53', 1, '54', 1, '55', 1, '56', 1, '57', 1,
    '65', 1, '66', 1, '67', 1, '68', 1, '69', 1, '70', 1);

my Mu $escapees := nqp::hash(
    '34', '"', '47', '/', '92', '\\', '98', 'b', '102', 'f', '110', 'n', '114', 'r', '116', 't');

my sub parse-string(str $text, int $pos is rw) {
    # first we gallop until the end of the string
    my int $startpos = $pos;
    my int $endpos;
    my int $ord;
    my int $has_hexcodes;
    my int $has_treacherous;
    my str $startcombiner = "";
    my Mu $treacherous;

    unless nqp::eqat($text, '"', $startpos - 1) {
        $startcombiner = tear-off-combiners($text, $startpos - 1);
    }

    loop {
        $ord = nqp::ordat($text, $pos);
        $pos = $pos + 1;

        if nqp::eqat($text, '"', $pos - 1) {
            $endpos = $pos - 1;
            last;
        } elsif $ord == 92 {
            if nqp::eqat($text, '"', $pos) or nqp::eqat($text, '\\', $pos) or nqp::eqat($text, 'b', $pos)
                or nqp::eqat($text, 'f', $pos) or nqp::eqat($text, 'n', $pos) or nqp::eqat($text, 'r', $pos)
                or nqp::eqat($text, 't', $pos) or nqp::eqat($text, '/', $pos) {
                $pos = $pos + 1;
            } elsif nqp::eqat($text, 'u', $pos) {
                die "unexpected end of document; was looking for four hexdigits." if nqp::chars($text) - $pos < 4;
                if nqp::existskey($hexdigits, nqp::ordat($text, $pos + 1))
                    and nqp::existskey($hexdigits, nqp::ordat($text, $pos + 2))
                    and nqp::existskey($hexdigits, nqp::ordat($text, $pos + 3))
                    and nqp::existskey($hexdigits, nqp::ordat($text, $pos + 4)) {
                    $pos = $pos + 4;
                    $has_hexcodes++;
                }
            } elsif nqp::existskey($escapees, nqp::ordat($text, $pos)) {
                # treacherous!
                $has_treacherous++;
                $treacherous := nqp::hash() unless $treacherous;
                my int $treach_ord = nqp::ordat($text, $pos);
                if nqp::existskey($treacherous, $treach_ord) {
                    nqp::bindkey($treacherous, $treach_ord, 1)
                } else {
                    nqp::bindkey($treacherous, $treach_ord, nqp::atkey($treacherous, $treach_ord) + 1)
                }
            } else {
                die "don't understand escape sequence '\\{ nqp::substr($text, $pos) }' at $pos";
            }
        }
    }

    $pos = $pos + 1;

    my str $raw = nqp::substr($text, $startpos, $endpos - $startpos);
    if not $has_treacherous {
        $raw = $raw
                .subst("\\n", "\n",     :g)
                .subst("\\r\\n", "\r\n",:g)
                .subst("\\r", "\r",     :g)
                .subst("\\t", "\t",     :g)
                .subst('\\"', '"',      :g)
                .subst('\\/',  '/',     :g)
                .subst('\\\\', '\\',    :g);
    } else {
        $raw = $raw.subst(/ \\ (<-[uU]>) /,
            -> $/ {
                if nqp::ordat($0, 0) == 117 || nqp::ordat($0, 0) == 85 {
                    $has_hexcodes++;
                    "\\u" # to be replaced in the next step.
                } elsif nqp::existskey($escapees, nqp::ordat($0, 0)) {
                    my str $replacement = nqp::atkey($escapees, nqp::ordat($0, 0));
                    $replacement ~ tear-off-combiners($0, 0);
                } else {
                    say "stumbled over unexpected escape code \\{ chr(nqp::ordat($0, 0)) } at { $startpos + $/.start }";
                }
            }, :g);
    }
    if $has_hexcodes {
        $raw = $raw.subst(/ \\ <[uU]> (<[a..z 0..9 A..Z]> ** 3) (.) /,
            -> $/ {
                my $lastchar = nqp::chr(nqp::ord($1.Str));
                my str $hexstr = $0 ~ $lastchar;

                if $lastchar eq $1.Str {
                    chr(:16($hexstr))
                } else {
                    chr(:16($hexstr)) ~ tear-off-combiners($1.Str, 0)
                }
            }, :x($has_hexcodes));
    }

    $pos = $pos - 1;

    $raw;
}

my sub parse-string-old(str $text, int $pos is rw) {
    my \result = parse-string-pieces($text, $pos);
    if result ~~ Str {
        return result;
    } else {
        return result.join("");
    }
}

my sub parse-string-pieces(str $text, int $pos is rw) {
    # fast-path a search through the string for the first "special" character ...
    my int $startpos = $pos;

    my str $result;

    my int $ord;

    my @pieces;

    unless nqp::eqat($text, '"', $startpos - 1) {
        # If the ord matches, but it doesn't eq, then we have lone
        # combining characters at the start of the string.
        $result = tear-off-combiners($text, $startpos - 1);
    }

    loop {
        $ord = nqp::ordat($text, $pos);
        $pos = $pos + 1;
        die "reached end of string while looking for end of quoted string." if $pos > nqp::chars($text);

        if $ord == 34 { # "
            $result = $result ~ nqp::substr($text, $startpos, $pos - 1 - $startpos);
            last;
        } elsif $ord == 92 { # \
            $result = $result ~ substr($text, $startpos, $pos - 1 - $startpos);
            @pieces.push: $result;

            if nqp::eqat($text, '"', $pos) {
                @pieces.push: '"';
            } elsif nqp::eqat($text, '\\', $pos) {
                @pieces.push: '\\';
            } elsif nqp::eqat($text, '/', $pos) {
                @pieces.push: '/';
            } elsif nqp::eqat($text, 'b', $pos) {
                @pieces.push: "\b";
            } elsif nqp::eqat($text, 'f', $pos) {
                @pieces.push: chr(0x0c);
            } elsif nqp::eqat($text, 'n', $pos) {
                @pieces.push: "\n";
            } elsif nqp::eqat($text, 'r\\n', $pos) {
                @pieces.push: "\r\n";
                $pos += 2;
            } elsif nqp::eqat($text, 'r', $pos) {
                @pieces.push: "\r";
            } elsif nqp::eqat($text, 't', $pos) {
                @pieces.push: "\t";
            } elsif nqp::eqat($text, 'u', $pos) {
                my $hexstr := nqp::substr($text, $pos + 1, 4);
                if nqp::chars($hexstr) != 4 {
                    die "expected exactly four alnum digits after \\u";
                }
                @pieces.push: chr(:16($hexstr));
                $pos = $pos + 4;
            } else {
                die "at $pos: I don't understand the escape sequence \\{ nqp::substr($text, $pos, 1) }";
            }

            if nqp::eqat($text, '"', $pos + 1) {
                $result = $result ~ @pieces[1];
                $pos = $pos + 2;
                last;
            } else {
                $pos = $pos + 1;
                my \subresult = parse-string-pieces($text, $pos);
                @pieces.append: subresult;
                return @pieces;
            }
        } elsif $ord < 14 && ($ord == 10 || $ord == 13 || $ord == 9) {
            die "at $pos: the only whitespace allowed in json strings are spaces";
        }
    }

    $result;
}

my sub parse-numeric(str $text, int $pos is rw) {
    my int $startpos = $pos;

    $pos = $pos + 1 while nqp::iscclass(nqp::const::CCLASS_NUMERIC, $text, $pos);

    my $residual := nqp::substr($text, $pos, 1);

    if $residual eq '.' {
        $pos = $pos + 1;

        $pos = $pos + 1 while nqp::iscclass(nqp::const::CCLASS_NUMERIC, $text, $pos);

        $residual := nqp::substr($text, $pos, 1);
    }

    if $residual eq 'e' || $residual eq 'E' {
        $pos = $pos + 1;

        if nqp::eqat($text, '-', $pos) || nqp::eqat($text, '+', $pos) {
            $pos = $pos + 1;
        }

        $pos = $pos + 1 while nqp::iscclass(nqp::const::CCLASS_NUMERIC, $text, $pos);
    }

    +(my $result := nqp::substr($text, $startpos - 1, $pos - $startpos + 1)) // die "at $pos: invalid number token $result.perl()";
}

my sub parse-obj(str $text, int $pos is rw) {
    my %result;

    my $key;
    my $value;

    nom-ws($text, $pos);

    if nqp::eqat($text, '}', $pos) {
        $pos = $pos + 1;
        %();
    } else {
        my $thing;
        loop {
            $thing = Any;

            if $key.DEFINITE {
                $thing = parse-thing($text, $pos)
            } else {
                nom-ws($text, $pos);

                if nqp::ordat($text, $pos) == 34 { # "
                    $pos = $pos + 1;
                    $thing = parse-string($text, $pos)
                } else {
                    die "at end of string: expected a quoted string for an object key" if $pos == nqp::chars($text);
                    die "at $pos: json requires object keys to be strings";
                }
            }
            nom-ws($text, $pos);

            #my str $partitioner = nqp::substr($text, $pos, 1);

            if nqp::eqat($text, ':', $pos)      and !($key.DEFINITE or $value.DEFINITE) {
                $key = $thing;
            } elsif nqp::eqat($text, ',', $pos) and     $key.DEFINITE and not $value.DEFINITE {
                $value = $thing;

                %result{$key} = $value;

                $key   = Any;
                $value = Any;
            } elsif nqp::eqat($text, '}', $pos) and     $key.DEFINITE and not $value.DEFINITE {
                $value = $thing;

                %result{$key} = $value;
                $pos = $pos + 1;
                last;
            } else {
                die "at end of string: unexpected end of object." if $pos == nqp::chars($text);
                die "unexpected { nqp::substr($text, $pos, 1) } in an object at $pos";
            }

            $pos = $pos + 1;
        }

        %result;
    }
}

my sub parse-array(str $text, int $pos is rw) {
    my @result;

    nom-ws($text, $pos);

    if nqp::eqat($text, ']', $pos) {
        $pos = $pos + 1;
        [];
    } else {
        my $thing;
        my str $partitioner;
        loop {
            $thing = parse-thing($text, $pos);
            nom-ws($text, $pos);

            $partitioner = nqp::substr($text, $pos, 1);
            $pos = $pos + 1;

            if $partitioner eq ']' {
                @result.push: $thing;
                last;
            } elsif $partitioner eq "," {
                @result.push: $thing;
            } else {
                die "at $pos, unexpected $partitioner inside list of things in an array";
            }
        }
        @result;
    }
}

my sub parse-thing(str $text, int $pos is rw) {
    nom-ws($text, $pos);

    my str $initial = nqp::substr($text, $pos, 1);

    $pos = $pos + 1;

    if ord($initial) == 34 { # "
        parse-string($text, $pos);
    } elsif $initial eq '[' {
        parse-array($text, $pos);
    } elsif $initial eq '{' {
        parse-obj($text, $pos);
    } elsif nqp::iscclass(nqp::const::CCLASS_NUMERIC, $initial, 0) || $initial eq '-' {
        parse-numeric($text, $pos);
    } elsif $initial eq 'n' {
        if nqp::eqat($text, 'ull', $pos) {
            $pos += 3;
            Any;
        } else {
            die "at $pos: i was expecting a 'null' but there wasn't one: { nqp::substr($text, $pos - 1, 10) }"
        }
    } elsif $initial eq 't' {
        if nqp::eqat($text, 'rue', $pos) {
            $pos = $pos + 3;
            True
        } else {
            die "at $pos: expected 'true', found { $initial ~ nqp::substr($text, $pos, 3) } instead.";
        }
    } elsif $initial eq 'f' {
        if nqp::eqat($text, 'alse', $pos) {
            $pos = $pos + 4;
            False
        } else {
            die "at $pos: expected 'false', found { $initial ~ nqp::substr($text, $pos, 4) } instead.";
        }
    } else {
        my str $rest = nqp::substr($text, $pos, 6);
        die "at $pos: can't parse objects starting in $initial yet (context: $rest)"
    }
}

sub from-json(Str() $text) is export {
    my str $ntext = $text;
    my int $length = $text.chars;

    my int $pos = 0;

    my $result = parse-thing($text, $pos);

    try nom-ws($text, $pos);

    if $pos != nqp::chars($text) {
        die "additional text after the end of the document: { substr($text, $pos).perl }";
    }

    $result;
}

# vi:syntax=perl6
