import ssl
from pyOpenSSL import SSL

# true positives
ssl.wrap_socket(ssl_version=ssl.PROTOCOL_SSLv2)
ssl.wrap_socket(ssl_version=ssl.PROTOCOL_SSLv3)
ssl.wrap_socket(ssl_version=ssl.PROTOCOL_TLSv1)

SSL.Context(method=SSL.SSLv2_METHOD)
SSL.Context(method=SSL.SSLv23_METHOD)
SSL.Context(method=SSL.SSLv3_METHOD)
SSL.Context(method=SSL.TLSv1_METHOD)

# not relevant
wrap_socket(ssl_version=ssl.PROTOCOL_SSLv3)
wrap_socket(ssl_version=ssl.PROTOCOL_TLSv1)
wrap_socket(ssl_version=ssl.PROTOCOL_SSLv2)

Context(method=SSL.SSLv3_METHOD)
Context(method=SSL.TLSv1_METHOD)
Context(method=SSL.SSLv2_METHOD)
Context(method=SSL.SSLv23_METHOD)

# true positive using flow

METHOD = SSL.SSLv2_METHOD
SSL.Context(method=METHOD)

# secure versions

ssl.wrap_socket(ssl_version=ssl.PROTOCOL_TLSv1_1)
SSL.Context(method=SSL.TLSv1_1_METHOD)

# possibly insecure default
ssl.wrap_socket()
