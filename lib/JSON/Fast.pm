use nqp;

unit module JSON::Fast;

# sub str-escape(str $text is copy) {
#     $text .= subst('\\', '\\\\', :g);
#     for flat 0..8, 11, 12, 14..0x1f -> $ord {
#         my str $chr = chr($ord);
#         if $text.contains($chr) {
#             $text .= subst($chr, '\\u' ~ $ord.fmt("%04x"), :g);
#         }
#     }
#     return $text.subst("\r\n", '\\r\\n',:g)\
#                 .subst("\n", '\\n',     :g)\
#                 .subst("\r", '\\r',     :g)\
#                 .subst("\t", '\\t',     :g)\
#                 .subst('"',  '\\"',     :g);
# }

sub str-escape($text) {
    $text.subst("\x5c", '\u005c', :g).subst("\x0", '\u0000', :g).subst("\x1", '\u0001', :g).subst("\x2", '\u0002', :g).subst("\x3", '\u0003', :g).subst("\x4", '\u0004', :g).subst("\x5", '\u0005', :g).subst("\x6", '\u0006', :g).subst("\x7", '\u0007', :g).subst("\x8", '\u0008', :g).subst("\x9", '\u0009', :g).subst("\xA", '\u000a', :g).subst("\xB", '\u000b', :g).subst("\xC", '\u000c', :g).subst("\xD", '\u000d', :g).subst("\xE", '\u000e', :g).subst("\xF", '\u000f', :g).subst("\x10", '\u0010', :g).subst("\x11", '\u0011', :g).subst("\x12", '\u0012', :g).subst("\x13", '\u0013', :g).subst("\x14", '\u0014', :g).subst("\x15", '\u0015', :g).subst("\x16", '\u0016', :g).subst("\x17", '\u0017', :g).subst("\x18", '\u0018', :g).subst("\x19", '\u0019', :g).subst("\x1A", '\u001a', :g).subst("\x1B", '\u001b', :g).subst("\x1C", '\u001c', :g).subst("\x1D", '\u001d', :g).subst("\x1E", '\u001e', :g).subst("\x1F", '\u001f', :g).subst("\x22", '\u0022', :g)
}

multi sub to-json($obj is copy, Bool :$pretty!, Int :$level = 0, Int :$spacing = 2) is export {
    return $obj ?? 'true' !! 'false' if $obj ~~ Bool;

    return 'null' if not $obj.defined;

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

    return "\"{str-escape($obj)}\"" if $obj ~~ Str;

    return „"$obj"“ if $obj ~~ Dateish;
    return „"{$obj.DateTime.Str}"“ if $obj ~~ Instant;

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

multi sub to-json($obj is copy) is export {
    return $obj ?? 'true' !! 'false' if $obj ~~ Bool;

    return 'null' if not $obj.defined;

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

    return "\"{str-escape($obj)}\"" if $obj ~~ Str;

    return „"$obj"“ if $obj ~~ Dateish;
    return „"{$obj.DateTime.Str}"“ if $obj ~~ Instant;

    if $obj ~~ Seq {
        $obj = $obj.cache
    }

    my $out;
    if $obj ~~ Positional {
        $out = '[';
        loop (my int $i=0,my int $max=$obj.elems-1; $i < $max; $i++) {
            $out ~= to-json($obj.AT-POS($i)) ~ ','
        }
        $out ~= to-json($obj.AT-POS($i)) ~ ']';
    } else {
        $out = '{';
        for $obj.keys -> $key {
            $out ~= „"{str-escape $key}":{to-json $obj.AT-KEY($key)},“;
        }
        $out .=chop;
        $out ~= '}';
    }
    return $out;
}

multi sub to-json-file(IO::Handle:D $fh, $_ is copy) is export {

    when Bool { $fh.print: ‚true‘ }

    when !.defined { $fh.print: ‚null‘ }

    when Int|Rat { $fh.print: .Str }

    when Num {
        if $_ === NaN | -Inf | Inf {
            if try $*JSON_NAN_INF_SUPPORT {
                $fh.print: .Str
            } else {
                $fh.print: ‚null‘
            }
        } else {
            $fh.print: .Str
        }
    }

    when Str { $fh.print: „"{str-escape .Str}"“ }

    when Dateish { $fh.print: „"$_"“ }
    when Instant { $fh.print: „"{.DateTime.Str}"“ }

    when Seq { .=cache }

    when Positional {
        $fh.print: '[';
            loop (my int $i=0,my int $max = .elems - 1; $i < $max; $i++) {
                to-json-file($fh, .AT-POS($i));
                $fh.print: ','
            }
            to-json-file($fh, .AT-POS($i));
            $fh.print: ']'
    }

    default {
        $fh.print: '{';
        my @keys = .keys;
        my $key;
        for @keys[0..^*-1] -> $key {
            $fh.print: „"{str-escape $key}":“;
            to-json-file($fh, .AT-KEY($key));
            $fh.print: ‚,‘
        }
        $key = @keys.tail;
        $fh.print: „"{str-escape $key}":“;
        to-json-file($fh, .AT-KEY($key));
        $fh.print: '}';
    }
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
    my int $textlength = nqp::chars($text);

    my int $ord;
    my int $has_hexcodes;
    my int $has_treacherous;
    my str $startcombiner = "";
    my Mu $treacherous;
    my Mu $escape_counts := nqp::hash();

    unless nqp::eqat($text, '"', $startpos - 1) {
        $startcombiner = tear-off-combiners($text, $startpos - 1);
    }

    loop {
        $ord = nqp::ordat($text, $pos);
        $pos = $pos + 1;

        if $pos > $textlength {
            die "unexpected end of document in string";
        }

        if nqp::eqat($text, '"', $pos - 1) {
            $endpos = $pos - 1;
            last;
        } elsif $ord == 92 {
            if nqp::eqat($text, '"', $pos) or nqp::eqat($text, '\\', $pos) or nqp::eqat($text, 'b', $pos)
                or nqp::eqat($text, 'f', $pos) or nqp::eqat($text, 'n', $pos) or nqp::eqat($text, 'r', $pos)
                or nqp::eqat($text, 't', $pos) or nqp::eqat($text, '/', $pos) {
                my str $character = nqp::substr($text, $pos, 1);
                if nqp::existskey($escape_counts, $character) {
                    nqp::bindkey($escape_counts, $character, nqp::atkey($escape_counts, $character) + 1);
                } else {
                    nqp::bindkey($escape_counts, $character, 1);
                }
                $pos = $pos + 1;
            } elsif nqp::eqat($text, 'u', $pos) {
                die "unexpected end of document; was looking for four hexdigits." if $textlength - $pos < 5;
                if nqp::existskey($hexdigits, nqp::ordat($text, $pos + 1))
                    and nqp::existskey($hexdigits, nqp::ordat($text, $pos + 2))
                    and nqp::existskey($hexdigits, nqp::ordat($text, $pos + 3))
                    and nqp::existskey($hexdigits, nqp::ordat($text, $pos + 4)) {
                    $pos = $pos + 4;
                    $has_hexcodes++;
                } else {
                    die "expected hexadecimals after \\u, but got \"{ nqp::substr($text, $pos - 1, 6) }\" at $pos";
                }
            } elsif nqp::existskey($escapees, nqp::ordat($text, $pos)) {
                # treacherous!
                $has_treacherous++;
                $treacherous := nqp::hash() unless $treacherous;
                my int $treach_ord = nqp::ordat($text, $pos);
                if nqp::existskey($treacherous, $treach_ord) {
                    nqp::bindkey($treacherous, $treach_ord, nqp::atkey($treacherous, $treach_ord) + 1)
                } else {
                    nqp::bindkey($treacherous, $treach_ord, 1)
                }
            } else {
                die "don't understand escape sequence '\\{ nqp::substr($text, $pos, 1) }' at $pos";
            }
        } elsif $ord == 9 or $ord == 10 {
            die "this kind of whitespace is not allowed in a string: { nqp::substr($text, $pos - 1, 1).perl } at {$pos - 1}";
        }
    }

    $pos = $pos + 1;

    my str $raw = nqp::substr($text, $startpos, $endpos - $startpos);
    if $startcombiner {
        $raw = $startcombiner ~ $raw
    }
    if not $has_treacherous {
        my @a;
        my @b;
        if nqp::existskey($escape_counts, "n") and nqp::existskey($escape_counts, "r") {
            @a.push("\\r\\n"); @b.push("\r\n");
        }
        if nqp::existskey($escape_counts, "n") {
            @a.push("\\n"); @b.push("\n");
        }
        if nqp::existskey($escape_counts, "r") {
            @a.push("\\r"); @b.push("\r");
        }
        if nqp::existskey($escape_counts, "t") {
            @a.push("\\t"); @b.push("\t");
        }
        if nqp::existskey($escape_counts, '"') {
            @a.push('\\"'); @b.push('"');
        }
        if nqp::existskey($escape_counts, "/") {
            @a.push("\\/"); @b.push("/");
        }
        if nqp::existskey($escape_counts, "\\") {
            @a.push("\\\\"); @b.push("\\");
        }

        $raw .= trans(@a => @b) if @a;
    } else {
        $raw = $raw.subst(/ \\ (<-[uU]>) /,
            -> $/ {
                if nqp::ordat($0.Str, 0) == 117 || nqp::ordat($0.Str, 0) == 85 {
                    $has_hexcodes++;
                    "\\u" # to be replaced in the next step.
                } elsif nqp::existskey($escapees, nqp::ordat($0.Str, 0)) {
                    my str $replacement = nqp::atkey($escapees, nqp::ordat($0.Str, 0));
                    $replacement ~ tear-off-combiners($0.Str, 0);
                } else {
                    die "stumbled over unexpected escape code \\{ chr(nqp::ordat($0.Str, 0)) } at { $startpos + $/.from }";
                }
            }, :g);
    }
    if $has_hexcodes {
        $raw = $raw.subst(/ \\ <[uU]> (<[a..z 0..9 A..Z]> ** 3) (.) /,
            -> $/ {
                my $lastchar = nqp::chr(nqp::ord($1.Str));
                my str $hexstr = $0.Str ~ $lastchar;
                my str $result;

                try {
                    if $lastchar eq $1.Str {
                        $result = chr(:16($hexstr))
                    } else {
                        $result = chr(:16($hexstr)) ~ tear-off-combiners($1.Str, 0)
                    }
                }
                die "Invalid hex string: $hexstr.perl()" without $result;
                $result
            }, :x($has_hexcodes));
    }

    $pos = $pos - 1;

    $raw;
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
        my str $rest = nqp::substr($text, $pos - 1, 8).perl;
        die "at $pos: expected a json object, but got $initial (context: $rest)"
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
