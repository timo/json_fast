use JSON::Fast;
use Test;

plan 1;

my $json := Q:to/JSON/;
{
  /* This is an example
     for block comment */
  "foo": "bar foo",  // Comments can
  "true": false,     // Improve readbility
  "number": 42,      // Number will always be 42
  /* Comments ignored while
     generating JSON from JSONC:  */
  // "object": {
  //   "test": "done"
  // },
  "array": [1, 2, 3]
}
JSON

is-deeply from-json($json, :allow-jsonc),
  {:array($[1, 2, 3]), :foo("bar foo"), :number(42), :true(Bool::False)},
  'did it parse ok, despite comments';
