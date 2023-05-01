use v6.d;
use Test;
use JSON::Fast;

is to-json(1+5i, converter => *.Str), "\"1+5i\"";
is to-json(9+8i, converter => *.re.round), "9";

multi sub convertit(Complex $i) { die "oh no" }
dies-ok { to-json 99+123i, converter => &convertit }

{
    use JSON::Fast <!pretty>;
    is to-json(1+5i, converter => *.Str), "\"1+5i\"";
    is to-json(9+8i, converter => *.re.round), "9";
}

done-testing;
