import java.io.IOException;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.ServletException;

public class SensitiveGetQuery extends HttpServlet {
	// BAD - Tests sending sensitive information in a GET request.
	public void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
		String username = request.getParameter("username");
		String password = request.getParameter("password");

		processUserInfo(username, password);
	}

	void processUserInfo(String username, String password) {
		System.out.println("username = " + username+"; password "+password);
	}

	// GOOD - Tests sending sensitive information in a POST request.
	public void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
		String password = request.getParameter("password");
		System.out.println("password = " + password);
	}
}
