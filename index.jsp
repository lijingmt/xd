<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<% response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<%@include file="includes/header.inc"%>
<wml>
  <head>
    <meta http-equiv="Cache-Control" content="max-age=0"/>
    <meta http-equiv="Cache-Control" content="no-cache" />
  </head>
  <card id="entry" title="<%=gamename_cn%>">
<%	

String hostStr = request.getHeader("Host");
if(internet_ip.equals(hostStr)||internet_addr.equals(hostStr))
{
	response.sendRedirect(index_url);
	return;
	}
String m_key = request.getParameter("m_key");
String mid = request.getParameter("mid");
if(mid==null){
	long ot = System.currentTimeMillis();
	mid=String.valueOf(ot);
}
if(m_key==null){
	long ot = System.currentTimeMillis();
	m_key=String.valueOf(ot);
}

String z = (String)request.getParameter("z");
if(z==null)
	z=(String)request.getSession().getAttribute("z");
	else
	request.getSession().setAttribute("z",z);

	String error_str = request.getParameter("err");
	String p_user = request.getParameter("_user");
	String p_pswd = request.getParameter("_pswd");
if(p_user == null)
	p_user = "";
if(p_pswd == null)
	p_pswd = "";

	if("1".equals(error_str))
	out.print("友情提示：用户名和密码不能为空，请修改后重试。 <br/>");  
	else if("2".equals(error_str))
	out.print("友情提示：为了你的安全，用户名和密码不能少于2个字符，请修改后重试。 <br/>");
	else if("3".equals(error_str))
	out.print("友情提示：用户名和密码只能是大小写字母或数字，请修改后重试。 <br/>");  
	else if("5".equals(error_str))
	out.print("友情提示：游戏账号和密码必须是2~12位的英文或者数字，或者两者的组合。 <br/>");  
	else if("4".equals(error_str))
	out.print("友情提示：您输入的用户名和密码认证失败或有人正在使用该帐号。 <br/>");  
	else if("6".equals(error_str))
	out.print("友情提示：您输入的用户名和密码认证失败，是否需要找回密码？ <br/>");  
	else if("7".equals(error_str))
	out.print("友情提示：系统犯晕了，请通知管理员。 <br/>");  
	%>
	<p>
	**仙道世界**<br/>
	=游戏登录=<br/>
	<a href="./demo.jsp?_user=<%=mid%>&amp;_pswd=<%=m_key%>">+游客体验</a><br/> 
	<a href="./regnew.jsp?<%=paraStringESC%>">新玩家注册</a><br/>
	请输入帐号<br/><input name="user" size="12" value="<%=p_user%>" maxlength="12" type="text" emptyok="false" format="*m"/><br/>
	请输入密码<br/><input name="pswd" size="12" value="<%=p_pswd%>" maxlength="12" type="text" emptyok="false" format="*m"/><br/>
	<anchor>进入游戏
	<go href="./entrycheck.jsp?regnewFlag=0&amp;game_fg=<%=game_pre%>" method="post">
	<postfield name="_user" value="$(user)" />
	<postfield name="_pswd" value="$(pswd)" />
	</go>
	</anchor><br/>
	<a href="./bandcount.jsp">冻结帐号</a><br/>
	<%@include file="/comm/tail.inc"%>
	</p>
	</card>
	</wml>
