use v6;
use lib 'lib';
use JSON::Fast;
use Test;

enum Bloop <Squee Moo Meep>;

is to-json(Bloop), "null", "enum type gives 'null'";
is to-json(Squee), '"Squee"', "enum value stringifies to its short name";
is to-json(Moo), '"Moo"', "enum value stringifies to its short name";
is to-json(Meep), '"Meep"', "enum value stringifies to its short name";

done-testing;
