// OK
/(.*?)a(?!(a+)b\2)/;
// NOT OK
/(.*?)a(?!(a+)b)\2(.*)/;
