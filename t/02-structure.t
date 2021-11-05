#!/usr/bin/env perl6
use v6;
use lib 'lib';
use JSON::Fast;
use Test;

my @t =
   '{ "a" : 1 }' => { a => 1 },
   '[]'          => [],
   '{}'          => {},
   '[ "a", "b"]' => [ "a", "b" ],
   '[3]'         => [3],
   '["\b\f\n\r\t"]' => ["\b\f\n\r\t"],
   '["\""]' => ['"'],
   '[{ "foo" : { "bar" : 3 } }, 78]' => [{ foo => { bar => 3 }}, 78],
   '[{ "a" : 3, "b" : 4 }]' => [{ a => 3, b => 4},],
    Q<<{
    "glossary": {
        "title": "example glossary",
		"GlossDiv": {
            "title": "S",
			"GlossList": {
                "GlossEntry": {
                    "ID": "SGML",
					"SortAs": "SGML",
					"GlossTerm": "Standard Generalized Markup Language",
					"Acronym": "SGML",
					"Abbrev": "ISO 8879:1986",
					"GlossDef": {
                        "para": "A meta-markup language, used to create markup languages such as DocBook.",
						"GlossSeeAlso": ["GML", "XML"]
                    },
					"GlossSee": "markup"
                }
            }
        }
    }
}
    >> => {
    "glossary" => {
        "title" => "example glossary",
		"GlossDiv" => {
            "title" => "S",
			"GlossList" => {
                "GlossEntry" => {
                    "ID" => "SGML",
					"SortAs" => "SGML",
					"GlossTerm" => "Standard Generalized Markup Language",
					"Acronym" => "SGML",
					"Abbrev" => "ISO 8879:1986",
					"GlossDef" => {
                        "para" => "A meta-markup language, used to create markup languages such as DocBook.",
						"GlossSeeAlso" => ["GML", "XML"]
                    },
					"GlossSee" => "markup"
                }
            }
        }
    }
},
;
plan @t + @t;

sub decontainerize(\obj) is raw {
    if obj ~~ Positional {
        @(obj).map({ decontainerize($_) }).List
    }
    elsif obj ~~ Associative {
        Map.new( @(obj).map({ .key => decontainerize(.value) }) )
    }
    else {
        obj<>
    }
}

for @t -> $p {
    my $s := try from-json($p.key);
    is-deeply $s, $p.value,
      "Correct data structure for «{$p.key.subst(/\n/, '\n', :g)}»";

    $s := try from-json($p.key, :immutable);
    is-deeply $s, decontainerize($p.value),
      "Correct data structure for «{$p.key.subst(/\n/, '\n', :g)}»";
}

# vim: ft=perl6
