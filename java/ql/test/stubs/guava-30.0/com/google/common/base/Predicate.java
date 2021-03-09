/*
 * Copyright (C) 2007 The Guava Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing permissions and limitations under
 * the License.
 */

package com.google.common.base;
import org.checkerframework.checker.nullness.qual.Nullable;

public interface Predicate<T> extends java.util.function.Predicate<T> {
  boolean apply(@Nullable T input);

  @Override
  boolean equals(@Nullable Object object);

  @Override
  default boolean test(@Nullable T input) {
    return false;
  }

}
