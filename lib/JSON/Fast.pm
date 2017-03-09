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

my sub parse-string(str $text, int $pos is rw) {
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
                @pieces.push: parse-string($text, $pos);
                $result = @pieces.join("");
                last;
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
