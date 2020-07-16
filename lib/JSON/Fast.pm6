=begin pod
=head1 JSON::Fast

a naive imperative json parser in pure perl6 (but with direct access to C<nqp::> ops), to evaluate performance against C<JSON::Tiny>. It is a drop-in replacement for C<JSON::Tiny>’s from-json and to-json subs, but it offers a few extra features.

Currently it seems to be about 4x faster and uses up about a quarter of the RAM JSON::Tiny would use.

This module also includes a very fast to-json function that tony-o created and lizmat later completely refactored.

=head2 Exported subroutines

=head3 to-json

=for code
    my $*JSON_NAN_INF_SUPPORT = 1; # allow NaN, Inf, and -Inf to be serialized.
    say to-json [<my Perl data structure>];
    say to-json [<my Perl data structure>], :!pretty;
    say to-json [<my Perl data structure>], :spacing(4);

    enum Blerp <Hello Goodbye>;
    say to-json [Hello, Goodbye]; # ["Hello", "Goodbye"]
    say to-json [Hello, Goodbye], :enums-as-value; # [0, 1]

Encode a Perl data structure into JSON. Takes one positional argument, which
is a thing you want to encode into JSON. Takes these optional named arguments:

=head4 pretty

C<Bool>. Defaults to C<True>. Specifies whether the output should be "pretty",
human-readable JSON. When set to false, will output json in a single line.

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

=head2 Additional features

=head3 Strings containing multiple json pieces

When the document contains additional non-whitespace after the first
successfully parsed JSON object, JSON::Fast will throw the exception
C<X::JSON::AdditionalContent>. If you expect multiple objects, you
can catch that exception, retrieve the parse result from its
C<parsed> attribute, and remove the first C<rest-position> characters
off of the string and restart parsing from there.

=end pod

use nqp;

unit module JSON::Fast:ver<0.12>;

our class X::JSON::AdditionalContent is Exception is export {
    has $.parsed;
    has $.parsed-length;
    has $.rest-position;

    method message {
        "JSON Input contained additional text after the document (parsed $.parsed-length chars, next non-whitespace lives at $.rest-position)"
    }
}

multi sub to-surrogate-pair(Int $ord) {
    my int $base   = $ord - 0x10000;
    my int $top    = $base +& 0b1_1111_1111_1100_0000_0000 +> 10;
    my int $bottom = $base +&               0b11_1111_1111;
    Q/\u/ ~ (0xD800 + $top).base(16) ~ Q/\u/ ~ (0xDC00 + $bottom).base(16);
}

multi sub to-surrogate-pair(Str $input) {
    to-surrogate-pair(nqp::ordat($input, 0));
}

my $tab := nqp::list_i(92,116); # \t
my $lf  := nqp::list_i(92,110); # \n
my $cr  := nqp::list_i(92,114); # \r
my $qq  := nqp::list_i(92, 34); # \"
my $bs  := nqp::list_i(92, 92); # \\

# Convert string to decomposed codepoints.  Run over that integer array
# and inject whatever is necessary, don't do anything if simple ascii.
# Then convert back to string and return that.
sub str-escape(\text) {
    my $codes := text.NFD;
    my int $i = -1;
    
    nqp::while(
      nqp::islt_i(++$i,nqp::elems($codes)),
      nqp::if(
        nqp::isle_i((my int $code = nqp::atpos_i($codes,$i)),92)
          || nqp::isge_i($code,128),
        nqp::if(                                           # not ascii
          nqp::isle_i($code,31),
          nqp::if(                                          # control
            nqp::iseq_i($code,10),
            nqp::splice($codes,$lf,$i++,1),                  # \n
            nqp::if(
              nqp::iseq_i($code,13),
              nqp::splice($codes,$cr,$i++,1),                 # \r
              nqp::if(
                nqp::iseq_i($code,9),
                nqp::splice($codes,$tab,$i++,1),               # \t
                nqp::stmts(                                    # other control
                  nqp::splice($codes,$code.fmt(Q/\u%04x/).NFD,$i,1),
                  ($i = nqp::add_i($i,5))
                )
              )
            )
          ),
          nqp::if(                                          # not control
            nqp::iseq_i($code,34),
            nqp::splice($codes,$qq,$i++,1),                  # "
            nqp::if(
              nqp::iseq_i($code,92),
              nqp::splice($codes,$bs,$i++,1),                 # \
              nqp::if(
                nqp::isge_i($code,0x10000),
                nqp::stmts(                                    # surrogates
                  nqp::splice(
                    $codes,
                    (my $surrogate := to-surrogate-pair($code.chr).NFD),
                    $i,
                    1
                  ),
                  ($i = nqp::sub_i(nqp::add_i($i,nqp::elems($surrogate)),1))
                )
              )
            )
          )
        )
      )
    );

    nqp::strfromcodes($codes)
}

our sub to-json(
  \obj,
  Bool :$pretty         = True,
  Int  :$level          = 0,
  int  :$spacing        = 2,
  Bool :$sorted-keys    = False,
  Bool :$enums-as-value = False,
) is export {

    my str @out;
    my str $spaces = ' ' x $spacing;
    my str $comma  = ",\n" ~ $spaces x $level;

#-- helper subs from here, with visibility to the above lexicals

    sub pretty-positional(\positional --> Nil) {
        $comma = nqp::concat($comma,$spaces);
        nqp::push_s(@out,'[');
        nqp::push_s(@out,nqp::substr($comma,1));

        for positional.list {
            jsonify($_);
            nqp::push_s(@out,$comma);
        }
        nqp::pop_s(@out);  # lose last comma

        $comma = nqp::substr($comma,0,nqp::sub_i(nqp::chars($comma),$spacing));
        nqp::push_s(@out,nqp::substr($comma,1));
        nqp::push_s(@out,']');
    }

    sub pretty-associative(\associative --> Nil) {
        $comma = nqp::concat($comma,$spaces);
        nqp::push_s(@out,'{');
        nqp::push_s(@out,nqp::substr($comma,1));
        my \pairs := $sorted-keys
          ?? associative.sort(*.key)
          !! associative.list;

        for pairs {
            nqp::push_s(@out,'"');
            nqp::push_s(@out, .key.Str);
            nqp::push_s(@out,'": ');
            jsonify(.value);
            nqp::push_s(@out,$comma);
        }
        nqp::pop_s(@out);  # lose last comma

        $comma = nqp::substr($comma,0,nqp::sub_i(nqp::chars($comma),$spacing));
        nqp::push_s(@out,nqp::substr($comma,1));
        nqp::push_s(@out,'}');
    }

    sub unpretty-positional(\positional --> Nil) {
        nqp::push_s(@out,'[');
        my int $before = nqp::elems(@out);
        for positional.list {
            jsonify($_);
            nqp::push_s(@out,",");
        }
        nqp::pop_s(@out) if nqp::elems(@out) > $before;  # lose last comma
        nqp::push_s(@out,']');
    }

    sub unpretty-associative(\associative --> Nil) {
        nqp::push_s(@out,'{');
        my \pairs := $sorted-keys
          ?? associative.sort(*.key)
          !! associative.list;

        my int $before = nqp::elems(@out);
        for pairs {
            nqp::push_s(@out, '"');
            nqp::push_s(@out, .key.Str);
            nqp::push_s(@out,'":');
            jsonify(.value);
            nqp::push_s(@out,",");
        }
        nqp::pop_s(@out) if nqp::elems(@out) > $before;  # lose last comma
        nqp::push_s(@out,'}');
    }

    sub jsonify(\obj --> Nil) {

        with obj {

            # basic ones
            if nqp::istype($_, Bool) {
                nqp::push_s(@out,obj ?? "true" !! "false");
            }
            elsif nqp::istype($_, IntStr) {
                jsonify(.Int);
            }
            elsif nqp::istype($_, RatStr) {
                jsonify(.Rat);
            }
            elsif nqp::istype($_, NumStr) {
                jsonify(.Num);
            }
            elsif nqp::istype($_, Enumeration) {
                if $enums-as-value {
                    jsonify(.value);
                }
                else {
                    nqp::push_s(@out,'"');
                    nqp::push_s(@out,str-escape(.key));
                    nqp::push_s(@out,'"');
                }
            }
            # Str and Int go below Enumeration, because there
            # are both Str-typed enums and Int-typed enums
            elsif nqp::istype($_, Str) {
                nqp::push_s(@out,'"');
                nqp::push_s(@out,str-escape($_));
                nqp::push_s(@out,'"');
            }

            # numeric ones
            elsif nqp::istype($_, Int) {
                nqp::push_s(@out,.Str);
            }
            elsif nqp::istype($_, Rat) {
                nqp::push_s(@out,.contains(".") ?? $_ !! "$_.0")
                  given .Str;
            }
            elsif nqp::istype($_, FatRat) {
                nqp::push_s(@out,.contains(".") ?? $_ !! "$_.0")
                  given .Str;
            }
            elsif nqp::istype($_, Num) {
                if nqp::isnanorinf($_) {
                    nqp::push_s(
                      @out,
                      $*JSON_NAN_INF_SUPPORT ?? obj.Str !! "null"
                    );
                }
                else {
                    nqp::push_s(@out,.contains("e") ?? $_ !! $_ ~ "e0")
                      given .Str;
                }
            }

            # iterating ones
            elsif nqp::istype($_, Seq) {
                jsonify(.cache);
            }
            elsif nqp::istype($_, Positional) {
                $pretty
                  ?? pretty-positional($_)
                  !! unpretty-positional($_);
            }
            elsif nqp::istype($_, Associative) {
                $pretty
                  ?? pretty-associative($_)
                  !! unpretty-associative($_);
            }

            # rarer ones
            elsif nqp::istype($_, Dateish) {
                nqp::push_s(@out,qq/"$_"/);
            }
            elsif nqp::istype($_, Instant) {
                nqp::push_s(@out,qq/"{.DateTime}"/);
            }
            elsif nqp::istype($_, Version) {
                jsonify(.Str);
            }

            # huh, what?
            else {
                die "Don't know how to jsonify {.^name}";
            }
        }
        else {
            nqp::push_s(@out,'null');
        }
    }

#-- do the actual work

    jsonify(obj);
    nqp::join("",@out)
}

my $ws := nqp::list_i;
nqp::bindpos_i($ws,$_,1) for 9,10,13,32;
nqp::push_i($ws,0);  # allow for -1 as value
my sub nom-ws(str $text, int $pos is rw --> Nil) {
    nqp::while(
      nqp::atpos_i($ws,nqp::ordat($text,$pos)),
      $pos = $pos + 1
    );
    die "reached end of string when looking for something"
      if $pos == nqp::chars($text);
}

my sub tear-off-combiners(\text, \pos) {
    text.substr(pos,1).NFD.skip.map( {
         $^ord > 0x10000
           ?? to-surrogate-pair($^ord)
           !! $^ord.chr
    } ).join
}

my $hexdigits := nqp::list;
nqp::bindpos($hexdigits,  48, 1);  # 0
nqp::bindpos($hexdigits,  49, 1);  # 1
nqp::bindpos($hexdigits,  50, 1);  # 2
nqp::bindpos($hexdigits,  51, 1);  # 3
nqp::bindpos($hexdigits,  52, 1);  # 4
nqp::bindpos($hexdigits,  53, 1);  # 5
nqp::bindpos($hexdigits,  54, 1);  # 6
nqp::bindpos($hexdigits,  55, 1);  # 7
nqp::bindpos($hexdigits,  56, 1);  # 8
nqp::bindpos($hexdigits,  57, 1);  # 9
nqp::bindpos($hexdigits,  65, 1);  # A
nqp::bindpos($hexdigits,  66, 1);  # B
nqp::bindpos($hexdigits,  67, 1);  # C
nqp::bindpos($hexdigits,  68, 1);  # D
nqp::bindpos($hexdigits,  69, 1);  # E
nqp::bindpos($hexdigits,  70, 1);  # F
nqp::bindpos($hexdigits,  97, 1);  # a
nqp::bindpos($hexdigits,  98, 1);  # b
nqp::bindpos($hexdigits,  99, 1);  # c
nqp::bindpos($hexdigits, 100, 1);  # d
nqp::bindpos($hexdigits, 101, 1);  # e
nqp::bindpos($hexdigits, 102, 1);  # f

my $escapees := nqp::list;
nqp::bindpos($escapees,  34, '"');
nqp::bindpos($escapees,  47, "/");
nqp::bindpos($escapees,  92, "\\");
nqp::bindpos($escapees,  98, "\b");
nqp::bindpos($escapees, 102, "\f");
nqp::bindpos($escapees, 110, "\n");
nqp::bindpos($escapees, 114, "\r");
nqp::bindpos($escapees, 116, "\t");

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
            if     nqp::eqat($text, '"', $pos) or nqp::eqat($text, '\\', $pos) or nqp::eqat($text, 'b', $pos)
                or nqp::eqat($text, 'f', $pos) or nqp::eqat($text,  'n', $pos) or nqp::eqat($text, 'r', $pos)
                or nqp::eqat($text, 't', $pos) or nqp::eqat($text,  '/', $pos) {
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
                    if      nqp::atpos($hexdigits, nqp::ordat($text, $pos + 1))
                        and nqp::atpos($hexdigits, nqp::ordat($text, $pos + 2))
                        and nqp::atpos($hexdigits, nqp::ordat($text, $pos + 3))
                        and nqp::atpos($hexdigits, nqp::ordat($text, $pos + 4)) {
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
            } elsif nqp::atpos($escapees, nqp::ordat($text, $pos)) {
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
    if not $has_treacherous and not $has_hexcodes and $escape_counts {
        my str @a;
        my str @b;
        if nqp::existskey($escape_counts, "b") {
            @a.push("\\b"); @b.push("\b");
        }
        if nqp::existskey($escape_counts, "f") {
            @a.push("\\f"); @b.push("\f");
        }
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
    } elsif $has_hexcodes or nqp::elems($escape_counts) {
        $raw = $raw.subst(/ \\ (<-[uU]>) || [\\ (<[uU]>) (<[a..f 0..9 A..F]> ** 3)]+ %(<[a..f 0..9 A..F]>) (:m <[a..f 0..9 A..F]>) /,
            -> $/ {
                if $0.elems > 1 || $0.Str eq "u" || $0.Str eq "U" {
                    my str @caps = $/.caps>>.value>>.Str;
                    my $result = $/;
                    my str $endpiece = "";
                    if (my $lastchar = nqp::chr(nqp::ord(@caps.tail))) ne @caps.tail {
                        $endpiece = tear-off-combiners(@caps.tail, 0);
                        @caps.pop;
                        @caps.push($lastchar);
                    }
                    my int @hexes;
                    for @caps -> $u, $first, $second {
                        @hexes.push(:16($first ~ $second).self);
                    }

                    CATCH {
                        die "Couldn't decode hexadecimal unicode escape { $result.Str } at { $startpos + $result.from }";
                    }

                    utf16.new(@hexes).decode ~ $endpiece;
                } else {
                    if nqp::atpos($escapees, nqp::ordat($0.Str, 0)) {
                        my str $replacement = nqp::atpos($escapees, nqp::ordat($0.Str, 0));
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
    my int $start = nqp::sub_i($pos,1);

    my int $end = nqp::findnotcclass(nqp::const::CCLASS_NUMERIC,
      $text, $pos, nqp::sub_i(nqp::chars($text),$pos));
    nqp::if(
      nqp::iseq_i(nqp::ordat($text, $end), 46),                      # .
      nqp::stmts(
        ($pos = nqp::add_i($end,1)),
        ($end = nqp::findnotcclass(nqp::const::CCLASS_NUMERIC,
          $text, $pos, nqp::sub_i(nqp::chars($text),$pos))
        )
      )
    );

    nqp::if(
      nqp::iseq_i((my int $ordinal = nqp::ordat($text, $end)), 101)  # e
       || nqp::iseq_i($ordinal, 69),                                 # E
      nqp::stmts(
        ($pos = nqp::add_i($end,1)),
        ($pos = nqp::add_i($pos,
          nqp::eqat($text, '-', $pos) || nqp::eqat($text, '+', $pos)
        )),
        ($end = nqp::findnotcclass(nqp::const::CCLASS_NUMERIC,
          $text, $pos, nqp::sub_i(nqp::chars($text),$pos))
        )
      )
    );

    my $result := nqp::substr($text, $start, nqp::sub_i($end,$start)).Numeric;
    nqp::if(
      nqp::istype($result, Failure),
      nqp::stmts(
        $result.Bool,  # handle Failure
        (die "at $pos: invalid number token $text.substr($start,$end - $start)")
      ),
      nqp::stmts(
        ($pos = $end),
        $result
      )
    )
}

my sub parse-obj(str $text, int $pos is rw) {
    my %result;
    my $hash := nqp::ifnull(
      nqp::getattr(%result,Map,'$!storage'),
      nqp::bindattr(%result,Map,'$!storage',nqp::hash)
    );

    nom-ws($text, $pos);
    my int $ordinal = nqp::ordat($text, $pos);
    nqp::if(
      nqp::iseq_i($ordinal, 125),  # }             {
      nqp::stmts(
        ($pos = nqp::add_i($pos,1)),
        %result
      ),
      nqp::stmts(
        my $descriptor := nqp::getattr(%result,Hash,'$!descriptor');
        nqp::stmts(  # this level is needed for some reason
          nqp::while(
            1,
            nqp::stmts(
              nqp::if(
                nqp::iseq_i($ordinal, 34),  # "
                (my $key := parse-string($text, $pos = nqp::add_i($pos,1))),
                (die nqp::if(
                  nqp::iseq_i($pos, nqp::chars($text)),
                  "at end of string: expected a quoted string for an object key",
                  "at $pos: json requires object keys to be strings"
                ))
              ),
              nom-ws($text, $pos),
              nqp::if(
                nqp::iseq_i(nqp::ordat($text, $pos), 58),  # :
                ($pos = nqp::add_i($pos, 1)),
                (die "expected to see a ':' after an object key")
              ),
              nom-ws($text, $pos),
              nqp::bindkey($hash, $key,
                nqp::p6scalarwithvalue($descriptor, parse-thing($text, $pos))),
              nom-ws($text, $pos),
              ($ordinal = nqp::ordat($text, $pos)),
              nqp::if(
                nqp::iseq_i($ordinal, 125),  # }  {
                nqp::stmts(
                  ($pos = nqp::add_i($pos,1)),
                  (return %result)
                ),
                nqp::unless(
                  nqp::iseq_i($ordinal, 44),  # ,
                  (die nqp::if(
                    nqp::iseq_i($pos, nqp::chars($text)),
                    "at end of string: unexpected end of object.",
                    "unexpected '{ nqp::substr($text, $pos, 1) }' in an object at $pos"
                  ))
                )
              ),
              nom-ws($text, $pos = nqp::add_i($pos,1)),
              ($ordinal = nqp::ordat($text, $pos)),
            )
          )
        )
      )
    )
}

my sub parse-array(str $text, int $pos is rw) {
    my @result;
    nqp::bindattr(@result, List, '$!reified',
      my $buffer := nqp::create(IterationBuffer));

    nom-ws($text, $pos);
    nqp::if(
      nqp::eqat($text, ']', $pos),
      nqp::stmts(
        ($pos = nqp::add_i($pos,1)),
        @result
      ),
      nqp::stmts(
        (my $descriptor := nqp::getattr(@result, Array, '$!descriptor')),
        nqp::while(
          1,
          nqp::stmts(
            (my $thing := parse-thing($text, $pos)),
            nom-ws($text, $pos),
            (my int $partitioner = nqp::ordat($text, $pos)),
            nqp::if(
              nqp::iseq_i($partitioner,93),  # ]
              nqp::stmts(
                nqp::push($buffer,nqp::p6scalarwithvalue($descriptor,$thing)),
                ($pos = nqp::add_i($pos,1)),
                (return @result)
              ),
              nqp::if(
                nqp::iseq_i($partitioner,44),  # ,
                nqp::stmts(
                  nqp::push($buffer,nqp::p6scalarwithvalue($descriptor,$thing)),
                  ($pos = nqp::add_i($pos,1))
                ),
                (die "at $pos, unexpected partitioner '{
                    nqp::substr($text,$pos,1)
                }' inside list of things in an array")
              )
            )
          )
        )
      )
    )
}

my sub parse-thing(str $text, int $pos is rw) {
    nom-ws($text, $pos);

    my int $ordinal = nqp::ordat($text, $pos);
    if nqp::iseq_i($ordinal,34) {  # "
        parse-string($text, $pos = $pos + 1)
    }
    elsif nqp::iseq_i($ordinal,91) {  # [
        parse-array($text, $pos = $pos + 1)
    }
    elsif nqp::iseq_i($ordinal,123) {  # {
        parse-obj($text, $pos = $pos + 1)
    }
    elsif nqp::iscclass(nqp::const::CCLASS_NUMERIC, $text, $pos)
      || nqp::iseq_i($ordinal,45) {  # -
        parse-numeric($text, $pos = $pos + 1)
    }
    elsif nqp::iseq_i($ordinal,116) && nqp::eqat($text,'true',$pos) {
        $pos = $pos + 4;
        True
    }
    elsif nqp::iseq_i($ordinal,102) && nqp::eqat($text,'false',$pos) {
        $pos = $pos + 5;
        False
    }
    elsif nqp::iseq_i($ordinal,110) && nqp::eqat($text,'null',$pos) {
        $pos = $pos + 4;
        Any
    }
    else {
        die "at $pos: expected a json object, but got '{
          nqp::substr($text, $pos, 8).perl
        }'";
    }
}

our sub from-json(Str() $text) is export {
    my int $pos;
    my $parsed := parse-thing($text, $pos);

    # not at the end yet?
    unless nqp::iseq_i($pos,nqp::chars($text)) {
        my int $parsed-length = $pos;
        try nom-ws($text, $pos);

        X::JSON::AdditionalContent.new(
          :$parsed, :$parsed-length, rest-position => $pos
        ).throw unless nqp::iseq_i($pos,nqp::chars($text));
    }

    $parsed
}

# vi:syntax=perl6
