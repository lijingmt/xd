<%@ page import="org.apache.log4j.*,
	org.apache.commons.lang.StringUtils,
	java.net.URL,
	java.net.HttpURLConnection,
	javax.naming.*,
	java.sql.Connection,
	javax.sql.DataSource,
	java.sql.PreparedStatement,
	java.io.BufferedReader,
	java.io.InputStream,
	java.io.InputStreamReader" %><%!

String exec_pike(String ...args) {
	try {
		java.util.LinkedList li= new java.util.LinkedList(java.util.Arrays.asList(args));
		li.add(0,"/usr/local/bin/pike");
		ProcessBuilder builder = new ProcessBuilder(li);
		builder.redirectErrorStream(true);
		Process process = builder.start();
		InputStream ins = process.getInputStream();
		BufferedReader br = new BufferedReader(new InputStreamReader(ins,"GB2312"));
		String result = "";
		String line;
		while ((line = br.readLine()) != null) {
			result += line;
		}
		return result;
	} catch (Throwable e) {
		return "0";
	}
}
%>
