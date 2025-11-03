#!/usr/bin/env perl6
use v6;
use lib 'lib';
use JSON::Fast;
use Test;

my Str @t =
    '{}',
    '{  }',
    ' { } ',
    '{ "a" : "b" }',
    '{ "a" : null }',
    '{ "a" : true }',
    '{ "a" : false }',
    '{ "a" : { } }',
    '[]',
    '[ ]',
    ' [ ] ',
    # stolen from JSON::XS, 18_json_checker.t, and adapted a bit
    Q«[
    "JSON Test Pattern pass1",
    {"object with 1 member":["array with 1 element"]},
    {},
    []
    ]»,
    Q«[1]»,
    Q«[true]»,
    Q«[-42]»,
    Q«[-42,true,false,null]»,
    Q«{ "integer": 1234567890 }»,
    Q«{ "real": -9876.543210 }»,
    Q«{ "e": 0.123456789e-12 }»,
    Q«{ "E": 1.234567890E+34 }»,
    Q«{ "":  23456789012E66 }»,
    Q«"A JSON payload is allowed to be a string."»,
    Q«99»,
    Q«5e1»,
    Q«-1»,
    Q«true»,
    Q«{ "zero": 0 }»,
    Q«{ "one": 1 }»,
    Q«{ "space": " " }»,
    Q«{ "quote": "\""}»,
    Q«{ "backslash": "\\"}»,
    Q«{ "controls": "\b\f\n\r\t"}»,
    Q«{ "slash": "/ & \/"}»,
    Q«{ "alpha": "abcdefghijklmnopqrstuvwyz"}»,
    Q«{ "ALPHA": "ABCDEFGHIJKLMNOPQRSTUVWYZ"}»,
    Q«{ "digit": "0123456789"}»,
    Q«{ "0123456789": "digit"}»,
    Q«{"special": "`1~!@#$%^&*()_+-={':[,]}|;.</>?"}»,
    Q«{"hex": "\u0123\u4567\u89AB\uCDEF\uabcd\uef4A"}»,
    Q«{"true": true}»,
    Q«{"false": false}»,
    Q«{"null": null}»,
    Q«{"array":[  ]}»,
    Q«{"object":{  }}»,
    Q«{"address": "50 St. James Street"}»,
    Q«{"url": "http://www.JSON.org/"}»,
    Q«{"comment": "// /* <!-- --"}»,
    Q«{"# -- --> */": " "}»,
    Q«{ " s p a c e d " :[1,2 , 3

,

4 , 5        ,          6           ,7        ],"compact":[1,2,3,4,5,6,7]}»,

    Q«{"jsontext": "{\"object with 1 member\":[\"array with 1 element\"]}"}»,
    Q«{"quotes": "&#34; \u0022 %22 0x22 034 &#x22;"}»,
    Q«{    "\/\\\"\uCAFE\uBABE\uAB98\uFCDE\ubcda\uef4A\b\f\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?"
: "A key can be any string"
    }»,
    Q«[    0.5 ,98.6
,
99.44
,

1066,
1e1,
0.1e1
    ]»,
    Q«[1e-1]»,
    Q«[1e00,2e+00,2e-00,"rosebud"]»,
    Q«[[[[[[[[[[[[[[[[[[["Not too deep"]]]]]]]]]]]]]]]]]]]»,
    Q«{
    "JSON Test Pattern pass3": {
        "The outermost value": "must be an object or array.",
        "In this test": "It is an object."
    }
}
»,
# from http://www.json.org/example.html
    Q«{
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
    »,
    Q«{"menu": {
  "id": "file",
  "value": "File",
  "popup": {
    "menuitem": [
      {"value": "New", "onclick": "CreateNewDoc()"},
      {"value": "Open", "onclick": "OpenDoc()"},
      {"value": "Close", "onclick": "CloseDoc()"}
    ]
  }
}}»,
    Q«{"widget": {
    "debug": "on",
    "window": {
        "title": "Sample Konfabulator Widget",
        "name": "main_window",
        "width": 500,
        "height": 500
    },
    "image": {
        "src": "Images/Sun.png",
        "name": "sun1",
        "hOffset": 250,
        "vOffset": 250,
        "alignment": "center"
    },
    "text": {
        "data": "Click Here",
        "size": 36,
        "style": "bold",
        "name": "text1",
        "hOffset": 250,
        "vOffset": 100,
        "alignment": "center",
        "onMouseUp": "sun1.opacity = (sun1.opacity / 100) * 90;"
    }
}}»,

    # JSONTestSuite tests
    Q«[""]»,
    Q«[]»,
    Q«["a"]»,
    Q«[false]»,
    Q«[null, 1, "1", {}]»,
    Q«[null]»,
    Q«[1
    ]»,
    Q« [1]»,
    Q«[1,null,null,null,2]»,
    Q«[1] »,
    Q«[123e65]»,
    Q«[0e+1]»,
    Q«[0e1]»,
    Q«[ 4]»,
    Q«[-0.000000000000000000000000000000000000000000000000000000000000000000000000000001]»,
    Q«[20e1]»,
    Q«[-0]»,
    Q«[-123]»,
    Q«[-1]»,
    Q«[1E22]»,
    Q«[1E-2]»,
    Q«[1E+2]»,
    Q«[123e45]»,
    Q«[123.456e78]»,
    Q«[1e-2]»,
    Q«[1e+2]»,
    Q«[123]»,
    Q«[123.456789]»,
    Q«{"asd":"sdf", "dfg":"fgh"}»,
    Q«{"asd":"sdf"}»,
    Q«{"a":"b","a":"c"}»,
    Q«{"a":"b","a":"b"}»,
    Q«{}»,
    Q«{"":0}»,
    Q«{"foo\u0000bar": 42}»,
    Q«{ "min": -1.0e+28, "max": 1.0e+28 }»,
    Q«{"x":[{"id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}], "id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}»,
    Q«{"a":[]}»,
    Q«{"title":"\u041f\u043e\u043b\u0442\u043e\u0440\u0430 \u0417\u0435\u043c\u043b\u0435\u043a\u043e\u043f\u0430" }»,
    Q«{
    "a":"b"
    }»,
    Q«["\u0060\u012A\u12AB"]»,
    Q«["\uD801\uDC37"]»,
    Q«["\uD83D\uDE39\uD83D\uDC8D"]»,
    Q«["\"\\\/\b\f\n\r\t"]»,
    Q«["\\u0000"]»,
    Q«["\""]»,
    Q«["a/*b*/c/*d//e"]»,
    Q«["\\a"]»,
    Q«["\\n"]»,
    Q«["\u0012"]»,
    Q«["\uFFFF"]»,
    Q«["asd"]»,
    Q«[ "asd"]»,
    Q«["\uD8FF\uDFFF"]»,
    Q«["new\u00A0line"]»,
    Q«["￿"]»,
    Q«["\u0000"]»,
    Q«["\u002C"]»,
    Q«["π"]»,
    Q«["asd "]»,
    Q«" "»,
    Q«["\uD834\uDD1E"]»,
    Q«["\u0821"]»,
    Q«["\u0123"]»,
    Q«"\u0061\u30AF\u30EA\u30B9"»,
    Q«["new\u000Aline"]»,
    Q«[""]»,
    Q«["\uA660"]»,
    Q«["⍂㈴⍂"]»,
    Q«["\u0022"]»,
    Q«["\uD8FF\uDFFE"]»,
    Q«["\uD83F\uDFFE"]»,
    Q«["\u200B"]»,
    Q«["\u2064"]»,
    Q«["\uFDD0"]»,
    Q«["\uFFFE"]»,
    Q«["\u005C"]»,
    Q«["€𝄞"]»,
    Q«["aa"]»,
    Q«false»,
    Q«42»,
    Q«-0.1»,
    Q«null»,
    Q«"asd"»,
    Q«true»,
    Q«""»,
    Q«["a"]
    »,
    Q«[true]»,
    Q«[] »,
;

my Str @n =
    '{ ',
    '{ 3 : 4 }',
    '{ 3 : tru }',  # not quite true
    '{ "a : false }', # missing quote
    # stolen from JSON::XS, 18_json_checker.t
    Q«{"Extra value after close": true} "misplaced quoted value"»,
    Q«{"Illegal expression": 1 + 2}»,
    Q«{"Illegal invocation": alert()}»,
    #Q«{"Numbers cannot have leading zeroes": 013}»,
    Q«{"Numbers cannot be hex": 0x14}»,
    Q«["Illegal backslash escape: \x15"]»,
    Q«[\naked]»,
    Q«["Illegal backslash escape: \017"]»,
# skipped: wo don't implement no stinkin' aritifical limits.
#    Q«[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[["Too deep"]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]»,
    Q«{"Missing colon" null}»,
    Q«["Unclosed array"»,
    Q«{"Double colon":: null}»,
    Q«{"Comma instead of colon", null}»,
    Q«["Colon instead of comma": false]»,
    Q«["Bad value", truth]»,
    Q«['single quote']»,
    qq<["\ttab\tcharacter	in	string	"]>,
    Q«["line
break"]»,
    Q«["line\
break"]»,
    Q«[0e]»,
    Q«{unquoted_key: "keys must be quoted"}»,
    Q«[0e+]»,
    Q«[0e+-1]»,
    Q«{"Comma instead if closing brace": true,»,
    Q«["mismatch"}»,
    Q«["extra comma",]»,
    Q«["double extra comma",,]»,
    Q«[   , "<-- missing value"]»,
    Q«["Comma after the close"],»,
    Q«["Extra close"]]»,
    Q«{"Extra comma": true,}»,

    # JSONTestSuite tests
    Q«{"\uDFAA":0}»,
    Q«["\uDADA"]»,
    Q«["\uD888\u1234"]»,
    Q«["\uD800\n"]»,
    Q«["\uDD1EA"]»,
    Q«["\uD800\uD8000\n"]»,
    Q«["\uD800"]»,
    Q«["\uD800abc"]»,
    Q«["\uDD1E\uD834"]»,
    Q«["\uDFAA"]»,
    Q«[1 true]»,
    Q«[a\uFFFF]»,
    Q«["": 1]»,
    Q«[""],»,
    Q«[,1]»,
    Q«[1,,2]»,
    Q«["x",,]»,
    Q«["x"]]»,
    Q«["",]»,
    Q«["x"»,
    Q«[x»,
    Q«[3[4]]»,
    Q«[1:2]»,
    Q«[,]»,
    Q«[-]»,
    Q«[,""]»,
    Q«["a",
    5
    ,1,»,
    Q«[1,]»,
    Q«[1,,]»,
    Q«["a"\f]»,
    Q«[*]»,
    Q«[""»,
    Q«[1,»,
    Q«[{}»,
    Q«[fals]»,
    Q«[nul]»,
    Q«[tru]»,
    Q«123 »,
    Q«[++1234]»,
    Q«[+1]»,
    Q«[+Inf]»,
    Q«[-2.]»,
    Q«[-NaN]»,
    Q«[.-1]»,
    Q«[.2e-3]»,
    Q«[0.1.2]»,
    Q«[0.3e+]»,
    Q«[0.3e]»,
    Q«[0.e1]»,
    Q«[0E+]»,
    Q«[0E]»,
    Q«[0e+]»,
    Q«[0e]»,
    Q«[1.0e+]»,
    Q«[1.0e-]»,
    Q«[1.0e]»,
    Q«[1 000.0]»,
    Q«[1eE2]»,
    Q«[2.e+3]»,
    Q«[2.e-3]»,
    Q«[2.e3]»,
    Q«[9.e+]»,
    Q«[Inf]»,
    Q«[NaN]»,
    Q«[1+2]»,
    Q«[0x1]»,
    Q«[0x42]»,
    Q«[Infinity]»,
    Q«[0e+-1]»,
    Q«[-123.123foo]»,
    Q«[-Infinity]»,
    Q«[-foo]»,
    Q«[- 1]»,
    Q«[-1x]»,
    Q«[1ea]»,
    Q«[1.]»,
    Q«[.123]»,
    Q«[1.2a-3]»,
    Q«[1.8011670033376514H-308]»,
    Q«["x", truth]»,
    Q«{[: "x"}»,
    Q«{"x", null}»,
    Q«{"x"::"b"}»,
    Q«{"a":"a" 123}»,
    Q«{key: 'value'}»,
    Q«{"a" b}»,
    Q«{:"b"}»,
    Q«{"a" "b"}»,
    Q«{"a":»,
    Q«{"a"»,
    Q«{l:1}»,
    Q«{9999E9999:1}»,
    Q«{null:null,null:null}»,
    Q«{"id":0,,,,,}»,
    Q«{'a':0}»,
    Q«{"id":0,}»,
    Q«{"a":"b"}/**/»,
    Q«{"a":"b"}/**//»,
    Q«{"a":"b"}//»,
    Q«{"a":"b"}/»,
    Q«{"a":"b",,"c":"d"}»,
    Q«{a: "b"}»,
    Q«{"a":"a»,
    Q«{ "foo" : "bar", "a" }»,
    Q«{"a":"b"}#»,
    Q« »,
    Q«["\uD800\"]»,
    Q«["\uD800\u"]»,
    Q«["\uD800\u1"]»,
    Q«["\uD800\u1x"]»,
    Q«[é]»,
    Q«["\"]»,
    Q«["\x00"]»,
    Q«["\\\"]»,
    Q«["\	"]»,
    Q«["\🌀"]»,
    Q«["\"]»,
    Q«["\u00A"]»,
    Q«["\uD834\u0D"]»,
    Q«["\uD800\uD800x"]»,
    Q«["\a"]»,
    Q«["\uQQQQ]»,
    Q«["\å"]»,
    Q«[\u0020"asd"]»,
    Q«[\n]»,
    Q«"»,
    Q«['single quote']»,
    Q«abc»,
    Q«["\»,
    Q«["new
    line"]»,
    Q«["	"]»,
    Q«""x»,
    Q«<.>»,
    Q«[<null>]»,
    Q«[]x»,
    Q«[1]]»,
    Q«["asd]»,
    Q«aå»,
    Q«[True]»,
    Q«1]»,
    Q«{"x": true,»,
    Q«[][]»,
    Q«]»,
    Q<<ï»{}>>,
    Q«å»,
    Q«[»,
    Q«»,
    Q«[ ]»,
    Q«2@»,
    Q«{}}»,
    Q«{"":»,
    Q«{"a":/*comment*/"b"}»,
    Q«{"a": true} "x"»,
    Q«['»,
    Q«[,»,
    Q«[{"":» x 10_000,
    Q«[{»,
    Q«["a»,
    Q«["a"»,
    Q«{»,
    Q«{]»,
    Q«{,»,
    Q«{[»,
    Q«{"a»,
    Q«{'a'»,
    Q«["\{["\{["\{["\{»,
    Q«é»,
    Q«*»,
    Q«{"a":"b"}#{}»,
    Q«[]a»,
    Q«[\u000A""]»,
    Q«[1»,
    Q«[ false, nul»,
    Q«[ true, fals»,
    Q«[ false, tru»,
    Q«{"asd":"asd"»,
    Q«å»,
    Q«[]»,
    Q«[⁠]», # contains a cheeky U+2060 Word Joiner in the middle
;

my Str @n-todo =
    # JSONTestSuite tests
    Q«[[]   ]»,
;

plan 2 * (@t + @n + @n-todo);

my Int $i = 0;
sub run-tests(Str @tests, Bool :$ok, Bool :$todo, Bool :$immutable) {
    for @tests -> $t {
        my Str $desc = $t;
        $desc .= subst: /\n.*$/, "\\n...[$i]" if $desc ~~ m/\n/;
        my Bool $parsed = False;
        try {
            from-json($t);
            $parsed = True;
            CATCH { default { diag $_ } }
        }
        my &test;
        if $ok {
            &test = &ok;
            $desc = "JSON string <$desc> parsed";
        } else {
            &test = &nok;
            $desc = "JSON string <$desc> NOT parsed";
        }
        todo "Test currently fails." if $todo;
        test $parsed, $desc;
        $i++;
    }
}

for False, True -> $immutable {
    run-tests(@t,      :$immutable, :ok);
    run-tests(@n,      :$immutable);
    run-tests(@n-todo, :$immutable, :todo);
}

# vim: ft=perl6 shiftwidth=4 expandtab
