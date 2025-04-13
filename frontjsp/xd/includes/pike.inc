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
	java.io.InputStreamReader" %>
	<%!
	String[] heads = {"xxxxxxxx"};

String[] parse(String moContent)
{
	if(moContent == null)
		return new String[0];
	moContent = moContent.trim();
	java.util.ArrayList retList = new java.util.ArrayList();

	for(int i =0; i < heads.length; i++)
	{
		if(moContent.length() > heads[i].length())	
		{
			String moHead = moContent.substring(0,heads[i].length());
			if(heads[i].equalsIgnoreCase(moHead))	
			{
				String uid = moContent.substring(heads[i].length());
				String gameName = moHead.substring(4);
				retList.add(gameName);
				retList.add(uid);
				break;
			}
		}
	}
	return (String[])retList.toArray(new String[0]);
}

String exec_pike(String ...args) {
	long set1 = System.currentTimeMillis();
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
		long cost = System.currentTimeMillis() - set1;
		logger.info("[exec_pike:" + StringUtils.join(args,' ') +  "] [result:" + result + "] [" + cost + "ms]");
		return result;
	} catch (Throwable e) {
		logger.error("[exec_pike:" + StringUtils.join(args,' ') +  "] [error] [" + (System.currentTimeMillis() - set1) + "ms]",e);
		return "0";
	}
}

public String invoke_url(String url,String uid,String point) {
	long set1 = System.currentTimeMillis();
	String dest = url + "?uid="+uid+"&point="+point;
	try {
		URL myurl = new URL(dest);
		HttpURLConnection urlconn = (HttpURLConnection) myurl.openConnection();
		urlconn.setConnectTimeout(10000);
		urlconn.setReadTimeout(30000);
		urlconn.setDoOutput(true);
		urlconn.setRequestMethod("GET");
		urlconn.connect();
		InputStream ins = urlconn.getInputStream();
		BufferedReader br = new BufferedReader(new InputStreamReader(ins));
		String result = "";
		String line;
		while ((line = br.readLine()) != null) {
			result += line;
		}
		urlconn.disconnect();
		long cost = System.currentTimeMillis() - set1;
		logger.debug("[invoke_url " + dest + "] [result:" + result + "] [" + cost + "ms]");
		return result;
	} catch (Throwable e) {
		logger.error("[invoike_url:" + dest + "] [error] [" + (System.currentTimeMillis() - set1) + 
				"ms]", e);
		return "0";
	}
}
%>
