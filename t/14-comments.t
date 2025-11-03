use JSON::Fast;
use Test;

plan 3;

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
  "array": [1, 2, /* 4, */ 3]
}
JSON

is-deeply from-json($json, :allow-jsonc),
  {:array($[1, 2, 3]), :foo("bar foo"), :number(42), :true(Bool::False)},
  'did it parse ok, despite comments';

dies-ok {from-json($json)}, "comments fail to parse in normal path";;

my $broken-comment := Q:to/JSON/;
{
    "this is not a valid comment:":
        /*/ 123
}
JSON

dies-ok { from-json($broken-comment, :allow-jsonc) }, '/*/ is not a valid full comment';
