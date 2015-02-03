# Sine Wave

This program provides a function that cycles through a set of strings
printing them one per line forming a sine wave. The program assumes an
80-column terminal.

```
uses "http://www.dallycot.net/ns/core/1.0#";
uses "http://www.dallycot.net/ns/math/1.0#";
uses "http://www.dallycot.net/ns/streams/1.0#";
uses "http://www.dallycot.net/ns/strings/1.0#";
uses "http://www.dallycot.net/ns/cli/1.0#";

sine-wave(strings, terminal-width -> 80) :> (
  number-of-strings := length(strings);
  max-string-length := last(max(length @ strings));
  middle := ceil(terminal-width div 2 - max-string-length div 2);
  multiplier := floor(middle - max-string-length div 2);
  blank-line := string-multiply(" ", terminal-width);

  (line) :> (
    string := strings[((line - 1) mod number-of-strings) + 1];
    tab := middle
         + multiplier * sin(line div 4, units -> "radians")
         + ceil((max-string-length - length(string)) div 2);

    string-take(blank-line, tab) ::> string;
  );
);

lines := print @ sine-wave([
  "Digital",
  "Humanities"
]) @ 1..200;

lines[200]
```
