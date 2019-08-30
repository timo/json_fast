use v6;
use lib 'lib';
use JSON::Fast;
use Test;

enum Bloop <Squee Moo Meep>;

is to-json(Bloop), "null", "enum type gives 'null'";
is to-json(Squee), '"Squee"', "enum value stringifies to its short name";
is to-json(Moo), '"Moo"', "enum value stringifies to its short name";
is to-json(Meep), '"Meep"', "enum value stringifies to its short name";

is to-json(Bloop, :enums-as-value), "null", "with enums-as-value: enum type gives 'null'";
is to-json(Squee, :enums-as-value), '0', "with enums-as-value: enum value stringifies to its integer value";
is to-json(Moo, :enums-as-value), '1', "with enums-as-value: enum value stringifies to its integer value";
is to-json(Meep, :enums-as-value), '2', "with enums-as-value: enum value jsonifies to its integer value";

enum Blerp (One => "Eins", Two => "Zwei", Three => "Drei");

is to-json(Blerp), "null", "enum type gives 'null'";
is to-json(One), '"One"', "enum value stringifies to its short name";
is to-json(Two), '"Two"', "enum value stringifies to its short name";
is to-json(Three), '"Three"', "enum value stringifies to its short name";

is to-json(Blerp, :enums-as-value), "null", "with enums-as-value: enum type gives 'null'";
is to-json(One, :enums-as-value), '"Eins"', "with enums-as-value: enum value stringifies to its integer value";
is to-json(Two, :enums-as-value), '"Zwei"', "with enums-as-value: enum value stringifies to its integer value";
is to-json(Three, :enums-as-value), '"Drei"', "with enums-as-value: enum value jsonifies to its integer value";


done-testing;
