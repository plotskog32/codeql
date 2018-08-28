import compose1 from 'just-compose';
import compose2 from 'compose-function';
import compose3 from 'lodash.flow';
import _ from 'lodash';
var compose4 = _.flow;

(function(){
    var source = SOURCE();

    SINK(source);

    function f1(){
        return source;
    }
    SINK(f1());

    function f2(){
        return source;
    }
    SINK(compose1(f2)());

    function f3(){

    }
    function f4(){
        return source;
    }
    SINK(compose1(f3, f4)());

    function f5(){
        return source;
    }
    SINK(compose1(o.f, f5)());

    function f6(){
        return source;
    }
    function f7(x){
        return x;
    }
    SINK(compose1(f6, f7)());

    function f8(x){
        return x;
    }
    function f9(x){
        return x;
    }
    SINK(compose1(f8, f9)(source));


    function f10(x){
        return x;
    }
    function f11(x){
        return x;
    }
    function f12(x){
        return x;
    }
    SINK(compose1(f10, f11, f12)(source));

    function f13(x){
        return x + 'foo' ;
    }
    SINK(compose1(f13)(source));

    function f14(){
        return undefined;
    }
    SINK(f14()); // NO FLOW

    function f15(){
        return source;
    }
    function f16(){
        return undefined;
    }
    SINK(compose1(f15, f16)()); // NO FLOW

    function f17(x, y){
        return y;
    }
    SINK(f17(source)); // NO FLOW

    function f18(x, y){
        return y;
    }
    SINK(f18(undefined, source));

    function f19(){
        return source;
    }
    SINK(compose2(f19)());

    function f20(){
        return source;
    }
    SINK(compose3(f20)());

    function f21(){
        return source;
    }
    SINK(compose4(f21)());

})();
