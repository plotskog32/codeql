(function(){
    var a = null;
    a();
    a?.();

    var b = undefined;
    b();
    b?.();
});
// semmle-extractor-options: --experimental
