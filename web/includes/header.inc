<%@ page import="org.apache.log4j.*,
	java.net.*,
	java.util.*,
	javax.naming.*,
	java.sql.Connection,
	javax.sql.DataSource,
	jakarta.servlet.http.HttpServletRequest,
	java.sql.PreparedStatement,
	java.io.*,
	java.security.*,
	com.spreada.utils.chinese.ZHConverter"
%>
<%@include file="config.inc"%>	
	<%!
	String[] paraList = {"from","z","mid","m_key"};

String queryParameterStringESC(HttpServletRequest request)
{
	StringBuffer sb = new StringBuffer();

	boolean havePre= false;
	for(int i=0; i < paraList.length;i++)
	{
		String name = paraList[i];
		String value = request.getParameter(name);
		if(value != null)
		{
			if(havePre)
				sb.append("&amp;");
			else 
				havePre =true;

			sb.append(name);
			sb.append("=");
			sb.append(value);
		}
	}
	return sb.toString();
}

String queryParameterString(HttpServletRequest request)
{
	StringBuffer sb = new StringBuffer();

	boolean havePre= false;
	for(int i=0; i < paraList.length;i++)
	{
		String name = paraList[i];
		String value = request.getParameter(name);
		if(value != null)
		{
			if(havePre)
				sb.append("&");
			else 
				havePre =true;
			sb.append(name);
			sb.append("=");
			sb.append(value);
		}
	}
	return sb.toString();
}

public int log_spread_info(String m_key,String mid,String game_id,String user_id,String ap_info)
{
	//return 0;

	if(m_key == null)
		return 0;

	long l = System.currentTimeMillis();
	int retInt = 0;
	Connection sqlCon = null;
	try
	{
		Context initContext = new InitialContext();
		Context envContext  = (Context)initContext.lookup("java:/comp/env");
		DataSource ds = (DataSource)envContext.lookup("jdbc/gamelog");
		sqlCon = ds.getConnection();

		String strSql = "insert into spread_infos(m_key,mid,game_id,user_id,log_time,ap_info) values (?,?,?,?,now(),?)";
		PreparedStatement pstmt = sqlCon.prepareStatement(strSql);
		pstmt.setString(1, m_key);
		pstmt.setString(2, mid);
		pstmt.setString(3, game_id);
		pstmt.setString(4, user_id);
		pstmt.setString(5, ap_info);
		retInt = pstmt.executeUpdate();
//loggerSpread.debug("[log_spread_info:"+m_key +","+ mid +"," +game_id + ","+user_id+","+ap_info+ "] [" + retInt + "] [succ] [" +
//				(System.currentTimeMillis() - l) + "ms]");

	}
	catch(Exception e)
	{
//loggerSpread.error("[log_spread_info:" + m_key +","+ mid +"," +game_id + ","+user_id+ "] [0] [error] ["+     
//				(System.currentTimeMillis() - l) + "ms]",e);    
	}
	finally
	{
		if(sqlCon != null )
			try
			{
				sqlCon.close();
			}
		catch(Exception ex)
		{       
			//loggerSpread.error("[log_spread_info:" + m_key +","+ mid +"," +game_id + ","+user_id+
			//		"] [sqlCon.close()] [error]",ex);
		}
	}
	return retInt;
}

public int log_spread_info(String m_key,String mid,String game_id,String user_id)
{
	//return 0;
	
	if(m_key == null)
		return 0;

	long l = System.currentTimeMillis();
	int retInt = 0;
	Connection sqlCon = null;
	try
	{
		Context initContext = new InitialContext();
		Context envContext  = (Context)initContext.lookup("java:/comp/env");
		DataSource ds = (DataSource)envContext.lookup("jdbc/gamelog");
		sqlCon = ds.getConnection();

		String strSql = "insert into spread_infos(m_key,mid,game_id,user_id,log_time) values (?,?,?,?,now())";
		PreparedStatement pstmt = sqlCon.prepareStatement(strSql);
		pstmt.setString(1, m_key);
		pstmt.setString(2, mid);
		pstmt.setString(3, game_id);
		pstmt.setString(4, user_id);
		retInt = pstmt.executeUpdate();
		//loggerSpread.debug("[log_spread_info:"+m_key +","+ mid +"," +game_id + ","+user_id+ "] [" + retInt + "] [succ] [" +
		//		(System.currentTimeMillis() - l) + "ms]");

	}
	catch(Exception e)
	{
		//loggerSpread.error("[log_spread_info:" + m_key +","+ mid +"," +game_id + ","+user_id+ "] [0] [error] ["+     
		//		(System.currentTimeMillis() - l) + "ms]",e);    
	}
	finally
	{
		if(sqlCon != null )
			try
			{
				sqlCon.close();
			}
		catch(Exception ex)
		{       
			//loggerSpread.error("[log_spread_info:" + m_key +","+ mid +"," +game_id + ","+user_id+
			//		"] [sqlCon.close()] [error]",ex);
		}
	}
	return retInt;
} 
boolean isLegalChar(String content)
{
	if(content == null)
		return false;

	String rightChar = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

	for (int i = 0; i < content.length(); i++)
	{
		char c = content.charAt(i);//字符串中的字符
		if ( rightChar.indexOf(c) == -1 )
			return false;
	}

	return true;
}

//以下函数用于sockt读写
void send(OutputStream  writer,byte bytes[]) throws IOException
{
	writer.write(bytes);
	writer.write("\n".getBytes());
	writer.flush();
}

String read(InputStream reader,String charset) throws IOException
{
	BufferedReader r = new BufferedReader(new InputStreamReader(reader,charset));
	String s = "";
	String ret ="";
	int n;
	try
	{
		char buff[]=new char[4096];
		n=r.read(buff,0,4096);
		while(n!=-1)
		{
			ret+=new String(buff,0,n);
			n=r.read(buff,0,4096);
		}
	}
	catch(Exception e)
	{
		e.printStackTrace();
	}
	return ret;
}

String legacyCommandValue(String value)
{
	if(value == null)
		return "";
	return value.replace("%","%%").replace(" ","%20");
}

String buildLegacyApiCommand(HttpServletRequest request,String baseCommand)
{
	String command = baseCommand == null || baseCommand.trim().length() == 0 ?
		"init" : baseCommand.trim();
	for(Enumeration names=request.getParameterNames();names.hasMoreElements();){
		String name = (String)names.nextElement();
		if(name == null || name.length() == 0 || name.charAt(0) == '_' ||
			"t".equals(name) || "arg".equals(name) || "info".equals(name) ||
			"cmd".equals(name) || "txd".equals(name) ||
			"userid".equals(name) || "password".equals(name) ||
			name.length() >= 5)
			continue;
		command += " "+name+"="+
			legacyCommandValue(request.getParameter(name));
	}
	String argument = request.getParameter("arg");
	if(argument == null || argument.length() == 0)
		argument = request.getParameter("_arg");
	if(argument != null && argument.length() > 0)
		command += " "+legacyCommandValue(argument);
	return command.replaceAll("  +"," ").trim();
}
%>
<%
try
{
	request.setCharacterEncoding("utf-8");
}catch(Exception uae)
{
	//com.lj.bbs.tools.setDefaultCharSet(request);
}
String mobile=request.getHeader("ia");
String paraString=queryParameterString(request);
String paraStringESC=queryParameterStringESC(request);
String favicon = "<link rel=\"icon\" type=\"image/x-icon\" href=\"images/favicon.ico\">";
%>
