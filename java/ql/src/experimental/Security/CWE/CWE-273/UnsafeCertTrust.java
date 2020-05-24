public static void main(String[] args) {
	{
		HostnameVerifier verifier = new HostnameVerifier() {
			@Override
			public boolean verify(String hostname, SSLSession session) {
				try { //GOOD: verify the certificate
					Certificate[] certs = session.getPeerCertificates();
					X509Certificate x509 = (X509Certificate) certs[0];
					check(new String[]{host}, x509);
					return true;
				} catch (SSLException e) {
					return false;
				}
			}
		};
		HttpsURLConnection.setDefaultHostnameVerifier(verifier);
	}

	{
		HostnameVerifier verifier = new HostnameVerifier() {
			@Override
			public boolean verify(String hostname, SSLSession session) {
				return true; // BAD: accept even if the hostname doesn't match
			}
		};
		HttpsURLConnection.setDefaultHostnameVerifier(verifier);
	}

	{
		X509TrustManager trustAllCertManager = new X509TrustManager() {
			@Override
			public void checkClientTrusted(final X509Certificate[] chain, final String authType)
				throws CertificateException {
			}

			@Override
			public void checkServerTrusted(final X509Certificate[] chain, final String authType)
				throws CertificateException {
				// BAD: trust any server cert
			}

			@Override
			public X509Certificate[] getAcceptedIssuers() {
				return null; //BAD: doesn't check cert issuer
			}
		};
	}

	{
		X509TrustManager trustCertManager = new X509TrustManager() {
			@Override
			public void checkClientTrusted(final X509Certificate[] chain, final String authType)
				throws CertificateException {
			}

			@Override
			public void checkServerTrusted(final X509Certificate[] chain, final String authType)
				throws CertificateException {
				pkixTrustManager.checkServerTrusted(chain, authType); //GOOD: validate the server cert
			}

			@Override
			public X509Certificate[] getAcceptedIssuers() {
				return new X509Certificate[0]; //GOOD: Validate the cert issuer
			}
		};
	}
}