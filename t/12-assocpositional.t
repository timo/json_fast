use Test;
use JSON::Fast;

plan 4;

class TestClass does Positional does Associative {
    method list {
        List.new(|do Pair.new($_.Str, $_) for 10 ... 1);
    }

    method sort(|c) {
        self.list.sort(|c)
    }

    method of {
        self.Positional::of();
    }
}

my $expected = %( do $_.Str => $_ for 10 ... 1 );

for Bool::.values X Bool::.values -> ($pretty, $sorted-keys) {
    my $jsonified = to-json TestClass.new, :$pretty, :$sorted-keys;
    my $back = from-json $jsonified;
    is-deeply $back, $expected;
}
