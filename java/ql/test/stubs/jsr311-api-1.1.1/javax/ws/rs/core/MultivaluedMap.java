/*
 * The contents of this file are subject to the terms
 * of the Common Development and Distribution License
 * (the "License").  You may not use this file except
 * in compliance with the License.
 * 
 * You can obtain a copy of the license at
 * http://www.opensource.org/licenses/cddl1.php
 * See the License for the specific language governing
 * permissions and limitations under the License.
 */

/*
 * MultivaluedMap.java
 *
 * Created on February 13, 2007, 2:30 PM
 *
 */

/*
 * Adapted from JAX-RS version 1.1.1 as available at
 *   https://search.maven.org/remotecontent?filepath=javax/ws/rs/jsr311-api/1.1.1/jsr311-api-1.1.1-sources.jar
 * Only relevant stubs of this file have been retained for test purposes.
 */

package javax.ws.rs.core;

import java.util.List;
import java.util.Map;

public interface MultivaluedMap<K, V> extends Map<K, List<V>> {
    
}
