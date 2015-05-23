use nqp;

module JSON::Fast;

proto to-json($) is export {*}

multi to-json(Real:D $d) { ~$d }
multi to-json(Bool:D $d) { $d ?? 'true' !! 'false'; }
multi to-json(Str:D  $d) {
    '"'
    ~ $d.trans(['"',  '\\',   "\b", "\f", "\n", "\r", "\t"]
            => ['\"', '\\\\', '\b', '\f', '\n', '\r', '\t'])\
            .subst(/<-[\c32..\c126]>/, { ord(~$_).fmt('\u%04x') }, :g)
    ~ '"'
}
multi to-json(Positional:D $d) {
    return  '[ '
            ~ $d.map(&to-json).join(', ')
            ~ ' ]';
}
multi to-json(Associative:D  $d) {
    return '{ '
            ~ $d.map({ to-json(.key) ~ ' : ' ~ to-json(.value) }).join(', ')
            ~ ' }';
}

multi to-json(Mu:U $) { 'null' }
multi to-json(Mu:D $s) {
    die "Can't serialize an object of type " ~ $s.WHAT.perl
}

my sub nom-ws(str $text, int $pos is rw) {
    loop {
        my int $wsord = nqp::ordat($text, $pos);
        last unless $wsord == 32 || $wsord == 10 || $wsord == 13 || $wsord == 9;
        ++$pos;
    }
    0;
}

constant %escaping_hash =
    { '"'  => '"',
      '\\' => '\\',
      '/'  => '/',
      'b'  => "\b",
      'f'  => chr(0x0c),
      'n'  => "\n",
      'r'  => "\r",
      't'  => "\t",
    };

my sub parse-string(str $text, int $pos is rw) {
    my int $startpos = $pos;

    my str $result;

    loop {
        my int $ord = nqp::ordat($text, $pos);
        ++$pos;

        if $ord == 34 { # "
            $result = nqp::substr($text, $startpos, $pos - 1 - $startpos);
            last;
        } elsif $ord == 92 { # \
            my @pieces;

            $result = substr($text, $startpos, $pos - 1 - $startpos);
            @pieces.push: $result;

            my str $kind = nqp::substr($text, $pos, 1);

            @pieces.push(my $hashresult) if $hashresult = %escaping_hash{$kind} // "";

            if not $hashresult and $kind eq 'u' {
                my $hexstr := nqp::substr($text, $pos + 1, 4);
                if nqp::chars($hexstr) != 4 {
                    die "expected exactly four alnum digits after \\u";
                }
                @pieces.push: chr(:16($hexstr));
                $pos += 4;
            } elsif not $hashresult {
                die "I don't understand the escape sequence \\$kind";
            }

            if nqp::eqat($text, '"', $pos + 1) {
                $result = $result ~ @pieces[1];
                $pos += 2;
                last;
            } else {
                ++$pos;
                @pieces.push: parse-string($text, $pos);
                $result = @pieces.join("");
                last;
            }
        } elsif $ord < 14 && ($ord == 10 || $ord == 13 || $ord == 9) {
            die "the only whitespace allowed in json strings are spaces";
        }
    }
    
    $result;
}

my sub parse-numeric(str $text, int $pos is rw) {
    my int $startpos = $pos;

    ++$pos while nqp::iscclass(nqp::const::CCLASS_NUMERIC, $text, $pos);

    my $residual := nqp::substr($text, $pos, 1);

    if $residual eq '.' {
        ++$pos;

        ++$pos while nqp::iscclass(nqp::const::CCLASS_NUMERIC, $text, $pos);

        $residual := nqp::substr($text, $pos, 1);
    }
    
    if $residual eq 'e' || $residual eq 'E' {
        ++$pos;

        if nqp::eqat($text, '-', $pos) || nqp::eqat($text, '+', $pos) {
            ++$pos;
        }

        ++$pos while nqp::iscclass(nqp::const::CCLASS_NUMERIC, $text, $pos);
    }

    +(my $result := nqp::substr($text, $startpos - 1, $pos - $startpos + 1)) // die "invalid number token $result.perl()";
}

my sub parse-null(str $text, int $pos is rw) {
    if nqp::eqat($text, 'ull', $pos) {
        $pos += 3;
        Any;
    } else {
        die "i was expecting a 'null' at $pos, but there wasn't one: { nqp::substr($text, $pos - 1, 10) }"
    }
}


my sub parse-obj(str $text, int $pos is rw) {
    my %result;

    my $key;
    my $value;

    my %string_intern := %*string_intern;

    nom-ws($text, $pos);

    if nqp::eqat($text, '}', $pos) {
        ++$pos;
        %();
    } else {
        loop {
            my $thing;

            if $key.defined {
                $thing = parse-thing($text, $pos)
            } else {
                nom-ws($text, $pos);

                if nqp::eqat($text, '"', $pos) {
                    ++$pos;
                    $thing = parse-string($text, $pos)
                } else {
                    die "json requires object keys to be strings";
                }
            }
            nom-ws($text, $pos);

            my $partitioner := nqp::substr($text, $pos, 1);
            ++$pos;

            if $partitioner eq ':'      and not $key.defined and not $value.defined {
                $key = (%string_intern{$thing} //= $thing);
            } elsif $partitioner eq ',' and     $key.defined and not $value.defined {
                $value = $thing;

                %result{$key} = $value;

                $key   = Nil;
                $value = Nil;
            } elsif $partitioner eq '}' and     $key.defined and not $value.defined {
                $value = $thing;

                %result{$key} = $value;
                last;
            } else {
                die "unexpected $partitioner in an object at $pos";
            }
        }

        %result;
    }
}

my sub parse-array(str $text, int $pos is rw) {
    my @result;

    nom-ws($text, $pos);

    if nqp::eqat($text, ']', $pos) {
        ++$pos;
        [];
    } else {
        loop {
            my $thing = parse-thing($text, $pos);
            nom-ws($text, $pos);

            my str $partitioner = nqp::substr($text, $pos, 1);
            ++$pos;

            if $partitioner eq ']' {
                @result.push: $thing;
                last;
            } elsif $partitioner eq "," {
                @result.push: $thing;
            } else {
                die "unexpected $partitioner inside list of things in an array";
            }
        }
        @result;
    }
}

my sub parse-thing(str $text, int $pos is rw) {
    nom-ws($text, $pos);

    my str $initial = nqp::substr($text, $pos, 1);

    ++$pos;

    if $initial eq '"' {
        parse-string($text, $pos);
    } elsif $initial eq '[' {
        parse-array($text, $pos);
    } elsif $initial eq '{' {
        parse-obj($text, $pos);
    } elsif nqp::iscclass(nqp::const::CCLASS_NUMERIC, $initial, 0) || $initial eq '-' {
        parse-numeric($text, $pos);
    } elsif $initial eq 'n' {
        parse-null($text, $pos);
    } elsif $initial eq 't' {
        if nqp::eqat($text, 'rue', $pos) {
            $pos += 3;
            True
        }
    } elsif $initial eq 'f' {
        if nqp::eqat($text, 'alse', $pos) {
            $pos += 4;
            False
        }
    } else {
        die "can't parse objects starting in $initial yet."
    }
}

sub from-json(Str() $text) is export {
    my str $ntext = $text;
    my int $length = $text.chars;

    my int $pos = 0;

    my %*string_intern;

    nom-ws($text, $pos);

    my str $initial = nqp::substr($text, $pos, 1);

    ++$pos;

    my $result;

    if $initial eq '{' {
        $result = parse-obj($ntext, $pos);
    } elsif $initial eq '[' {
        $result = parse-array($ntext, $pos);
    } else {
        die "a JSON string ought to be a list or an object";
    }

    try nom-ws($text, $pos);

    if $pos != nqp::chars($text) {
        die "additional text after the end of the document: { substr($text, $pos).perl }";
    }

    $result;
}
