use Test;

plan 8;

my @array   = 1,2,3;
my $string := @array.raku.subst(" ", "", :global);
my $list   := @array.List;

{
    use JSON::Fast <immutable !pretty>;
    is to-json($list),
      $string,
      "to-json is not pretty";
    is to-json($list, :pretty),
      "[\n  1,\n  2,\n  3\n]",
      "to-json override to pretty works";

    is-deeply from-json($string),
      $list,
      "from-json is immutable";
    is-deeply from-json($string, :!immutable),
      @array,
      "from-json override to immutable works";
}

{
    use JSON::Fast;
    is to-json($list),
      "[\n  1,\n  2,\n  3\n]",
      "to-json is not pretty";
    is to-json($list, :!pretty),
      $string,
      "to-json override to pretty works";

    is-deeply from-json($string),
      @array,
      "from-json is immutable";
    is-deeply from-json($string, :immutable),
      $list,
      "from-json override to immutable works";
}
