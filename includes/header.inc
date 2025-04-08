<%@ page import="org.apache.log4j.*,
	org.apache.commons.lang.StringUtils,
	java.net.*,
	java.util.*,
	javax.naming.*,
	java.sql.Connection,
	javax.sql.DataSource,
	java.sql.PreparedStatement,
	java.io.*,
	java.security.*,
	com.dogstart.util.*"
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
		loggerSpread.debug("[log_spread_info:"+m_key +","+ mid +"," +game_id + ","+user_id+","+ap_info+ "] [" + retInt + "] [succ] [" +
				(System.currentTimeMillis() - l) + "ms]");

	}
	catch(Exception e)
	{
		loggerSpread.error("[log_spread_info:" + m_key +","+ mid +"," +game_id + ","+user_id+ "] [0] [error] ["+     
				(System.currentTimeMillis() - l) + "ms]",e);    
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
			loggerSpread.error("[log_spread_info:" + m_key +","+ mid +"," +game_id + ","+user_id+
					"] [sqlCon.close()] [error]",ex);
		}
	}
	return retInt;
}

public int log_spread_info(String m_key,String mid,String game_id,String user_id)
{
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
		loggerSpread.debug("[log_spread_info:"+m_key +","+ mid +"," +game_id + ","+user_id+ "] [" + retInt + "] [succ] [" +
				(System.currentTimeMillis() - l) + "ms]");

	}
	catch(Exception e)
	{
		loggerSpread.error("[log_spread_info:" + m_key +","+ mid +"," +game_id + ","+user_id+ "] [0] [error] ["+     
				(System.currentTimeMillis() - l) + "ms]",e);    
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
			loggerSpread.error("[log_spread_info:" + m_key +","+ mid +"," +game_id + ","+user_id+
					"] [sqlCon.close()] [error]",ex);
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

boolean isComputer(HttpServletRequest request)
{
	String[] forbiddenList = {"robooSimulator","wapie.tav.cn","M3Gate","WinWAP","Windows NT","Windows 98","Windows ME","HaoDew"};
	String ua= request.getHeader("User-Agent");
	String remote_host = request.getRemoteHost();
	if(ua == null)
		return false;

	for(int i=0;i<forbiddenList.length;i++)
	{
		if(ua.contains(forbiddenList[i]))
		{
		//	loggerCommon.debug("[IP:"+remote_host+"] [User-Agent:"+ua+"]");
			return true;
		}
	}

	return false;
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
%>
<%
try
{
	request.setCharacterEncoding("utf-8");
}catch(Exception uae)
{
	com.lj.bbs.tools.setDefaultCharSet(request);
}
String mobile=request.getHeader("ia");
String paraString=queryParameterString(request);
String paraStringESC=queryParameterStringESC(request);                                                                      

%>
