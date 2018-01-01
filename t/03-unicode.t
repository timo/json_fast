#!/usr/bin/env perl6
use v6;
use lib 'lib';
use JSON::Fast;
use Test;


my @t =
    '{ "a" : "b\u00E5" }' => { 'a' => 'bå' },
    '[ "\u2685" ]' => [ '⚅' ],
    '[ "̅hello" ]' => [ "\x[305]hello" ],
    '{ "̅hello": "goodbye" }' => { "\x[305]hello" => "goodbye" },
    '[ "\ud83c\udded\ud83c\uddf7" ]' => [ "🇭🇷" ];

my @out =
    "\{\"a\": \"bå\"}",
    '["⚅"]',
    '["̅hello"]',
    '{"̅hello": "goodbye"}',
    '["\uD83C\uDDED\uD83C\uDDF7"]';

plan (+@t * 2 + 2 + 2);
my $i = 0;
for @t -> $p {
    my $json = from-json($p.key);
    is-deeply $json, $p.value, "Correct data structure for «{$p.key}»";
    is to-json($json, :pretty(False)), @out[$i++], 'to-json test';
}

my $zalgostring = utf8.new(34,32,205,149,205,136,204,171,205,137,90,204,182,65,204,155,76,204,183,204,159,204,177,71,204,188,205,150,204,157,204,173,205,153,205,141,204,150,205,159,79,204,184,205,153,204,169,204,152,33,204,176,204,178,205,148,204,166,205,150,204,177,204,175,205,161,34).decode('utf8');
lives-ok {
    from-json $zalgostring;
}, "parse a mean zalgo string";

is $zalgostring.&from-json.&to-json, $zalgostring, "zalgostring roundtrips";

given "\c[QUOTATION MARK] \c[REVERSE SOLIDUS, REVERSE SOLIDUS]u0004 \c[REVERSE SOLIDUS]u00037 \c[REVERSE SOLIDUS, REVERSE SOLIDUS, COMBINING TILDE] \c[QUOTATION MARK]" {
    is .&from-json, " \c[REVERSE SOLIDUS]u0004 \x[3]7 \c[REVERSE SOLIDUS, COMBINING TILDE] ";
    is .&from-json.&to-json, .self;
}
