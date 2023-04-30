use Test;
use JSON::Fast;

plan 5;

sub assert-sorted($obj, @keys = $obj.keys, :$message) {
    my $result = to-json($obj, :sorted-keys);
    is $_, .sort.List, $message given $result.comb(/@keys/).List;
}

sub assert-sorted-custom($obj, @keys = $obj.keys, Mu :$sort-option, :$message) {
    my $result = to-json($obj, :sorted-keys($sort-option));
    is $_, .sort($sort-option).List, $message given $result.comb(/@keys/).List;
}

assert-sorted
    { foo => 1,
      bar => 2,
      quux => 3,
      aeiou => 4 };

assert-sorted
    [{ foo => 1,
      bar => 2,
      quux => 3,
      aeiou => 4 },],
    <foo bar quux aeiou>,
    message => "sorted keys even inside other constructs";

assert-sorted
    {
        "aaaa" => {
            "aaac" => 1,
            "aaab" => 2,
            "aaax" => 3,
            "aaaf" => 4
        },
        "bbbb" => {
            "ccca" => 1,
            "cccz" => 2,
            "cccf" => 3,
            "cccy" => 4
        }
    },
    <aaaa aaab aaac aaaf aaax bbbb ccca cccf cccy cccz>,
    message => "sorted outer dictionary with inner sorted dictionaries";

sub numberword-to-number($_) {
 <one two three four five six seven eight nine>.first(.words.tail, :k)
}

assert-sorted-custom
        [{ foo-one =>  1,
           foo-three => 3,
           foo-four => 4,
           foo-two =>  2,
           foo-nine => 9,
           foo-eight => 8,
           foo-five => 5,
           }],
    <foo-one foo-two foo-three foo-four foo-five foo-eight foo-nine>,
    sort-option => &numberword-to-number,
    message => "sorted with custom transformation function (1 argument)";

assert-sorted-custom
        [{ foo-one =>  1,
           foo-three => 3,
           foo-four => 4,
           foo-two =>  2,
           foo-nine => 9,
           foo-eight => 8,
           foo-five => 5,
        }],
    <foo-one foo-two foo-three foo-four foo-five foo-eight foo-nine>,
    sort-option => { numberword-to-number($^a) cmp numberword-to-number($^b) },
    message => "sorted with custom transformation function (2 arguments)";
