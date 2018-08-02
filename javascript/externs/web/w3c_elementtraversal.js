/*
 * Copyright 2009 The Closure Compiler Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @fileoverview Definitions for DOM Element Traversal interface.
 *  This file depends on w3c_dom1.js.
 *  The whole file has been fully type annotated.
 *  Created from:
 *    http://www.w3.org/TR/ElementTraversal/#ecmascript-bindings
 *
 * @externs
 * @author arv@google.com (Erik Arvidsson)
 */

/**
 * @typedef {?(Document|DocumentFragment|Element)}
 * @see https://dom.spec.whatwg.org/#parentnode
 */
var ParentNode;

/**
 * @typedef {?(Element|CharacterData)}
 * @see https://dom.spec.whatwg.org/#nondocumenttypechildnode
 */
var NonDocumentTypeChildNode;

/**
 * @type {Element}
 * @see https://developer.mozilla.org/En/DOM/Element.firstElementChild
 */
Element.prototype.firstElementChild;

/**
 * @type {Element}
 * @see https://developer.mozilla.org/En/DOM/Element.lastElementChild
 */
Element.prototype.lastElementChild;

/**
 * @type {Element}
 * @see https://developer.mozilla.org/En/DOM/Element.previousElementSibling
 */
Element.prototype.previousElementSibling;

/**
 * @type {Element}
 * @see https://developer.mozilla.org/En/DOM/Element.nextElementSibling
 */
Element.prototype.nextElementSibling;

/**
 * @type {number}
 * @see https://developer.mozilla.org/En/DOM/Element.childElementCount
 */
Element.prototype.childElementCount;

/**
 * @type {?Element}
 * @see https://dom.spec.whatwg.org/#dom-parentnode-firstelementchild
 */
Document.prototype.firstElementChild;

/**
 * @type {?Element}
 * @see https://dom.spec.whatwg.org/#dom-parentnode-lastelementchild
 */
Document.prototype.lastElementChild;

/**
 * @type {number}
 * @see https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
 */
Document.prototype.childElementCount;

/**
 * @type {?Element}
 * @see https://dom.spec.whatwg.org/#dom-parentnode-firstelementchild
 */
DocumentFragment.prototype.firstElementChild;

/**
 * @type {?Element}
 * @see https://dom.spec.whatwg.org/#dom-parentnode-lastelementchild
 */
DocumentFragment.prototype.lastElementChild;

/**
 * @type {number}
 * @see https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
 */
DocumentFragment.prototype.childElementCount;

/**
 * @type {?Element}
 * @see https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-previouselementsibling
 */
CharacterData.prototype.previousElementSibling;

/**
 * @type {?Element}
 * @see https://dom.spec.whatwg.org/#dom-nondocumenttypechildnode-nextelementsibling
 */
CharacterData.prototype.nextElementSibling;
