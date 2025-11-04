use v6;
use JSON::Fast;
use Test;

my $input = q«[1, 2, 3]{"a": 99, "b": 123} "foo"»;
my @results;

my $rounds = 0;

loop {
    $rounds++;
    last if $rounds > 100;

    @results.push: from-json($input);

    CATCH {
        when X::JSON::AdditionalContent {
            @results.push: .parsed;
            $input = $input.substr(.rest-position)
        }
    }
    last
};

is $rounds, 3, "right number of parses";
is-deeply @results[0], $[1, 2, 3], "first result";
is-deeply @results[1], ${"a" => 99, "b" => 123}, "second result";
is-deeply @results[2], "foo", "third result";

done-testing;
