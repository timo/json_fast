=begin pod
=head1 JSON::Fast

a naive imperative json parser in pure perl6 (but with direct access to C<nqp::> ops), to evaluate performance against C<JSON::Tiny>. It is a drop-in replacement for C<JSON::Tiny>'s from-json and to-json subs, but it offers a few extra features.

Currently it seems to be about 4x faster and uses up about a quarter of the RAM JSON::Tiny would use.

This module also includes a very fast to-json function that tony-o created in tony-o/perl6-json-faster.

=head2 Exported subroutines

=head3 to-json

=for code
    my $*JSON_NAN_INF_SUPPORT = 1; # allow NaN, Inf, and -Inf to be serialized.
    say to-json [<my Perl data structure>];
    say to-json [<my Perl data structure>], :!pretty;
    say to-json [<my Perl data structure>], :spacing(4);

Encode a Perl data structure into JSON. Takes one positional argument, which
is a thing you want to encode into JSON. Takes these optional named arguments:

=head4 pretty

C<Bool>. Defaults to C<True>. Specifies whether the output should be "pretty",
human-readable JSON.

=head4 spacing

C<Int>. Defaults to C<2>. Applies only when C<pretty> is C<True>.
Controls how much spacing there is between each nested level of the output.

=head4 sorted-keys

C<Bool>, defaults to C<False>. Specifies whether keys from objects should
be sorted before serializing them to a string or if C<$obj.keys> is good enough.

=head3 from-json

=for code
    my $x = from-json '["foo", "bar", {"ber": "bor"}]';
    say $x.perl;
    # outputs: $["foo", "bar", {:ber("bor")}]

Takes one positional argument that is coerced into a C<Str> type and represents
a JSON text to decode. Returns a Perl datastructure representing that JSON.

=end pod

use nqp;

unit module JSON::Fast;

sub str-escape(str $text is copy) {
    $text .= subst(/ :m <[\\ "]> /,
        -> $/ {
            my str $str = $/.Str;
            if $str eq "\\" {
                "\\\\"
            } elsif nqp::ordat($str, 0) == 92 {
                "\\\\" ~ tear-off-combiners($str, 0)
            } elsif $str eq "\"" {
                "\\\""
            } else {
                "\\\"" ~ tear-off-combiners($str, 0)
            }
        },
        :g);
    for flat 0..8, 11, 12, 14..0x1f -> $ord {
        my str $chr = chr($ord);
        if $text.contains($chr) {
            $text .= subst($chr, '\\u' ~ $ord.fmt("%04x"), :g);
        }
    }
    $text = $text.subst("\r\n", '\\r\\n',:g)\
                .subst("\n", '\\n',     :g)\
                .subst("\r", '\\r',     :g)\
                .subst("\t", '\\t',     :g);
    $text;
}

sub to-json($obj is copy, Bool :$pretty = True, Int :$level = 0, Int :$spacing = 2, Bool :$sorted-keys = False) is export {
    return $obj ?? 'true' !! 'false' if $obj ~~ Bool;

    return 'null' if not $obj.defined;

    # Handle allomorphs like IntStr.new(0, '') properly.
    return $obj.Int.Str if $obj ~~ Int;
    return to-json($obj.Rat, :$pretty, :$level, :$spacing, :$sorted-keys) if $obj ~~ RatStr;

    if $obj ~~ Rat {
        my $result = $obj.Str;
        unless $obj.contains(".") {
            return $result ~ ".0";
        }
        return $result;
    }

    if $obj ~~ Num {
        # Allomorph support for NumStr, too.
        $obj = $obj.Num;
        if $obj === NaN || $obj === -Inf || $obj === Inf {
            if try $*JSON_NAN_INF_SUPPORT {
                return $obj.Str;
            } else {
                return "null";
            }
        } else {
            my $result = $obj.Str;
            unless $result.contains("e") {
                return $result ~ "e0";
            }
            return $result;
        }
    }

    return "\"" ~ str-escape($obj) ~ "\"" if $obj ~~ Str;

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
          $out ~= to-json($i, :level($level+1), :$spacing, :$pretty, :$sorted-keys) ~ ',';
          $spacer();
        }
    }
    else {
        my @keys = $obj.keys;

        if ($sorted-keys) {
            @keys = @keys.sort;
        }

        for @keys -> $key {
            $out ~= "\"" ~
                    ($key ~~ Str ?? str-escape($key) !! $key) ~
                    "\": " ~
                    to-json($obj{$key}, :level($level+1), :$spacing, :$pretty, :$sorted-keys) ~
                    ',';
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
                loop {
                    die "unexpected end of document; was looking for four hexdigits." if $textlength - $pos < 5;
                    if nqp::existskey($hexdigits, nqp::ordat($text, $pos + 1))
                        and nqp::existskey($hexdigits, nqp::ordat($text, $pos + 2))
                        and nqp::existskey($hexdigits, nqp::ordat($text, $pos + 3))
                        and nqp::existskey($hexdigits, nqp::ordat($text, $pos + 4)) {
                        $pos = $pos + 4;
                    } else {
                        die "expected hexadecimals after \\u, but got \"{ nqp::substr($text, $pos - 1, 6) }\" at $pos";
                    }
                    $pos++;
                    if nqp::eqat($text, '\u', $pos) {
                        $pos++;
                    } else {
                        last
                    }
                }
                $has_hexcodes++;
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
                $pos++;
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
    if not $has_treacherous and not $has_hexcodes {
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
            @a.push("/"), @b.push("\\/");
        }
        if nqp::existskey($escape_counts, "\\") {
            @a.push("\\\\"); @b.push("\\");
        }
        $raw .= trans(@a => @b) if @a;
    } else {
        $raw = $raw.subst(/ \\ (<-[uU\\]>) || <!after \\> [\\\\]* <( [\\ (<[uU]>) (<[a..f 0..9 A..F]> ** 3)]+ %(<[a..f 0..9 A..F]>) (:m <[a..f 0..9 A..F]>) /,
            -> $/ {
                if $0.elems > 1 || $0.Str eq "u" || $0.Str eq "U" {
                    my str @caps = $/.caps>>.value>>.Str;
                    my $result = $/;
                    my str $endpiece = "";
                    if my $lastchar = nqp::chr(nqp::ord(@caps.tail)) ne @caps.tail {
                        $endpiece = tear-off-combiners(@caps.tail, 0);
                        @caps.pop;
                        @caps.push($lastchar);
                    }
                    my int @hexes;
                    for @caps -> $u, $first, $second {
                        @hexes.push(:16($first ~ $second).self);
                    }

                    CATCH {
                        .note;
                        die "Couldn't decode hexadecimal unicode escape { $result.Str } ({ $result.caps>>.value>>.Str }) at { $startpos + $result.from }";
                    }

                    utf16.new(@hexes).decode ~ $endpiece;
                } else {
                    if nqp::existskey($escapees, nqp::ordat($0.Str, 0)) {
                        my str $replacement = nqp::atkey($escapees, nqp::ordat($0.Str, 0));
                        $replacement ~ tear-off-combiners($0.Str, 0);
                    } else {
                        die "stumbled over unexpected escape code \\{ chr(nqp::ordat($0.Str, 0)) } at { $startpos + $/.from }";
                    }
                }
            }, :g);
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
