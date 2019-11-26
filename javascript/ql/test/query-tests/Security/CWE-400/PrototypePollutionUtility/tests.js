import dummy from 'somewhere';

function copyUsingForIn(dst, src) {
    for (let key in src) {
        if (dst[key]) {
            copyUsingForIn(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // NOT OK
        }
    }
}

function copyUsingKeys(dst, src) {
    Object.keys(src).forEach(key => {
        if (dst[key]) {
            copyUsingKeys(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // NOT OK
        }
    });
}

function copyRest(dst, ...sources) {
    for (let source of sources) {
        for (let key in source) {
            copyRestAux(dst, source[key], key);
        }
    }
}

function copyRestAux(dst, value, key) {
    let dstValue = dst[key];
    if (dstValue) {
        copyRest(dstValue, value);
    } else {
        dst[key] = value; // NOT OK
    }
}

function copyProtoGuarded(dst, src) {
    for (let key in src) {
        if (key === "__proto__") continue;
        if (dst[key]) {
            copyProtoGuarded(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // NOT OK
        }
    }
}

function copyCtorGuarded(dst, src) {
    for (let key in src) {
        if (key === "constructor") continue;
        if (dst[key]) {
            copyCtorGuarded(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // NOT OK
        }
    }
}

function copyDoubleGuarded(dst, src) {
    for (let key in src) {
        if (key === "constructor" || key === "__proto__") continue;
        if (dst[key]) {
            copyDoubleGuarded(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // OK
        }
    }
}

function isSafe(key) {
    return key !== "__proto__" && key !== "constructor" && key !== "prototype";
}

function copyComplex(dst, src) {
    for (let key in src) {
        if (isSafe(key)) {
            if (dst[key]) {
                copyComplex(dst[key], src[key]);
            } else {
                dst[key] = src[key]; // OK
            }
        }
    }
}

function copyHasOwnProperty(dst, src) {
    for (let key in src) {
        // Guarding the recursive case by dst.hasOwnProperty is safe,
        // since '__proto__' and 'constructor' are not own properties of the destination object.
        if (dst.hasOwnProperty(key)) {
            copyHasOwnProperty(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // OK
        }
    }
}

function copyHasOwnPropertyBad(dst, src) {
    for (let key in src) {
        // Guarding using src.hasOwnProperty is *not* effective,
        // since '__proto__' and 'constructor' are own properties in the payload.
        if (!src.hasOwnProperty(key)) continue; // Not safe
        if (dst[key]) {
            copyHasOwnPropertyBad(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // NOT OK
        }
    }
}

let _hasOwnProp = Object.prototype.hasOwnProperty;

function copyHasOwnPropertyTearOff(dst, src) {
    for (let key in src) {
        if (_hasOwnProp.call(dst, key)) {
            copyHasOwnPropertyTearOff(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // OK
        }
    }
}

function shallowExtend(dst, src) {
    for (let key in src) {
        dst[key] = src[key]; // OK
    }
}

function transform(src, fn) {
    if (typeof src !== 'object') return fn(src);
    for (let key in src) {
        src[key] = transform(src[key], fn); // OK
    }
    return src;
}

function clone(src) {
    if (typeof src !== 'object') return src;
    let result = {};
    for (let key in src) {
        result[key] = clone(src[key]); // OK
    }
    return result;
}

function higherOrderRecursion(dst, src, callback) {
    for (let key in src) {
        if (dst[key]) {
            callback(dst, src, key);
        } else {
            dst[key] = src[key]; // NOT OK
        }
    }
}

function higherOrderRecursionEntry(dst, src) {
    higherOrderRecursion(dst, src, (dst, src, key) => {
        higherOrderRecursionEntry(dst[key], src[key]);
    });
}

function instanceofObjectGuard(dst, src) {
    for (let key in src) {
        let dstValue = dst[key];
        if (typeof dstValue === 'object' && dstValue instanceof Object) {
            instanceofObjectGuard(dstValue, src[key]);
        } else {
            dst[key] = src[key]; // OK
        }
    }
}

let blacklist = ["__proto__", "constructor"];

function copyWithBlacklist(dst, src) {
    for (let key in src) {
        if (blacklist.indexOf(key) >= 0) continue;
        if (dst[key]) {
            copyWithBlacklist(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // OK
        }
    }
}

function copyUsingPlainForLoop(dst, src) {
    let keys = Object.keys(src);
    for (let i = 0; i < keys.length; ++i) {
        let key = keys[i];
        if (dst[key]) {
            copyUsingPlainForLoop(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // NOT OK
        }
    }
}

function copyUsingPlainForLoopNoAlias(dst, src) {
    // Like copyUsingPlainForLoop, but with keys[i] duplicated at every use-site
    let keys = Object.keys(src);
    for (let i = 0; i < keys.length; ++i) {
        if (dst[key]) {
            copyUsingPlainForLoopNoAlias(dst[keys[i]], src[keys[i]]);
        } else {
            dst[keys[i]] = src[keys[i]]; // NOT OK - but not flagged
        }
    }
}

function deepSet(map, key1, key2, value) {
    if (!map[key1]) {
        map[key1] = Object.create(null);
    }
    map[key1][key2] = value; // OK
}

function deepSetCaller(data) {
    let map1 = Object.create(null);
    let map2 = Object.create(null);
    for (let key in data) {
        deepSet(map1, key, 'x', data[key]);
        deepSet(map2, 'x', key, data[key]);
    }
}

function deepSetBad(map, key1, key2, value) {
    if (!map[key1]) {
        map[key1] = Object.create(null);
    }
    map[key1][key2] = value; // NOT OK - object literal can flow here
}

function deepSetCallerBad(data) {
    let map1 = Object.create(null);
    for (let key in data) {
        deepSetBad({}, key, 'x', data[key]); // oops
        deepSetBad(map1, 'x', key, data[key]);
    }
}

function maybeCopy(x) {
    if (x && typeof x === 'object') {
        return {...x};
    } else {
        return x;
    }
}

function mergeWithCopy(dst, src) {
    if (dst == null) return src;
    let result = maybeCopy(dst);
    for (let key in src) {
        if (src.hasOwnProperty(key)) {
            result[key] = mergeWithCopy(dst[key], src[key]); // OK
        }
    }
    return result;
}

function copyUsingEntries(dst, src) {
    Object.entries(src).forEach(entry => {
        let key = entry[0];
        let value = entry[1];
        if (dst[key]) {
            copyUsingEntries(dst[key], value);
        } else {
            dst[key] = value; // NOT OK
        }
    });
}

function copyUsingReflect(dst, src) {
    Reflect.ownKeys(src).forEach(key => {
        if (dst[key]) {
            copyUsingReflect(dst[key], src[key]);
        } else {
            dst[key] = src[key]; // NOT OK
        }
    });
}

function copyWithPath(dst, src, path) {
    for (let key in src) {
        if (src.hasOwnProperty(key)) {
            if (dst[key]) {
                copyWithPath(dst[key], src[key], path ? path + '.' + key : key);
            } else {
                let target = {};
                target[path] = {};
                target[path][key] = src[key]; // OK
                doSomething(target);
            }
        }
    }
    return dst;
}
