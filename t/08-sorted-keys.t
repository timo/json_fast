use Test;
use JSON::Fast;

plan 3;

sub assert-sorted($obj, @keys = $obj.keys, :$message) {
    my $result = to-json($obj, :sorted-keys);
    is .List, .sort.List, $message given $result.comb(/@keys/);
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
