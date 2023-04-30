[![Build Status](https://travis-ci.org/timo/json_fast.svg?branch=master)](https://travis-ci.org/timo/json_fast)

JSON::Fast
==========

A naive imperative JSON parser in pure Raku (but with direct access to `nqp::` ops), to evaluate performance against `JSON::Tiny`. It is a drop-in replacement for `JSON::Tiny`’s from-json and to-json subs, but it offers a few extra features.

Currently it seems to be about 4x faster and uses up about a quarter of the RAM JSON::Tiny would use.

This module also includes a very fast to-json function that tony-o created and lizmat later completely refactored.

Exported subroutines
--------------------

### to-json

        my $*JSON_NAN_INF_SUPPORT = 1; # allow NaN, Inf, and -Inf to be serialized.
        say to-json [<my Raku data structure>];
        say to-json [<my Raku data structure>], :!pretty;
        say to-json [<my Raku data structure>], :spacing(4);

    enum Blerp <Hello Goodbye>;
    say to-json [Hello, Goodbye]; # ["Hello", "Goodbye"]
    say to-json [Hello, Goodbye], :enums-as-value; # [0, 1]

Encode a Raku data structure into JSON. Takes one positional argument, which is a thing you want to encode into JSON. Takes these optional named arguments:

#### pretty

`Bool`. Defaults to `True`. Specifies whether the output should be "pretty", human-readable JSON. When set to false, will output json in a single line.

#### spacing

`Int`. Defaults to `2`. Applies only when `pretty` is `True`. Controls how much spacing there is between each nested level of the output.

#### sorted-keys

Specifies whether keys from objects should be sorted before serializing them to a string or if `$obj.keys` is good enough. Defaults to `False`. Can also be specified as a `Callable` with the same type of argument that the `.sort` method accepts to provide alternate sorting methods.

#### enum-as-value

`Bool`, defaults to `False`. Specifies whether `enum`s should be json-ified as their underlying values, instead of as the name of the `enum`.

### from-json

        my $x = from-json '["foo", "bar", {"ber": "bor"}]';
        say $x.perl;
        # outputs: $["foo", "bar", {:ber("bor")}]

Takes one positional argument that is coerced into a `Str` type and represents a JSON text to decode. Returns a Raku datastructure representing that JSON.

#### immutable

`Bool`. Defaults to `False`. Specifies whether `Hash`es and `Array`s should be rendered as immutable datastructures instead (as `Map` / `List`. Creating an immutable data structures is mostly saving on memory usage, and a little bit on CPU (typically around 5%).

This also has the side effect that elements from the returned structure can now be iterated over directly because they are not containerized.

#### allow-jsonc

`BOOL`. Defaults to `False`. Specifies whether commmands adhering to the [JSONC standard](https://changelog.com/news/jsonc-is-a-superset-of-json-which-supports-comments-6LwR) are allowed.

        my %hash := from-json "META6.json".IO.slurp, :immutable;
        say "Provides:";
        .say for %hash<provides>;

Additional features
-------------------

### Adapting defaults of "from-json"

In the `use` statement, you can add the string `"immutable"` to make the default of the `immutable` parameter to the `from-json` subroutine `True`, rather than False.

        use JSON::Fast <immutable>;  # create immutable data structures by default

### Adapting defaults of "to-json"

In the `use` statement, you can add the strings `"!pretty"`, `"sorted-keys"` and/or `"enums-as-value"` to change the associated defaults of the `to-json` subroutine.

        use JSON::FAST <!pretty sorted-keys enums-as-value>;

### Strings containing multiple json pieces

When the document contains additional non-whitespace after the first successfully parsed JSON object, JSON::Fast will throw the exception `X::JSON::AdditionalContent`. If you expect multiple objects, you can catch that exception, retrieve the parse result from its `parsed` attribute, and remove the first `rest-position` characters off of the string and restart parsing from there.

