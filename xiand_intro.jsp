<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<%response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<%@include file="includes/header.inc"%>
<wml>
<head>
	<meta http-equiv="Cache-Control" content="max-age=0"/>
	<meta http-equiv="Cache-Control" content="no-cache" />
</head>
<card title="仙道网游"><%                                                            
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
else if(z==null)
z="";
else
request.getSession().setAttribute("z",z);
%>
<p align="left">
<small>
	<a href="<%=reg_url%>?&amp;<%=paraStringESC%>">免费注册</a><br/>
	<a href="./demo.jsp?_user=<%=mid%>&amp;_pswd=<%=m_key%>">+游客体验+</a><br/>
</small>
<img src="images/logo.png" alt="仙道"/><br/>
仙道大战，一触即发！<br/>
<small>
	<a href="<%=reg_url%>?from=3&amp;<%=paraStringESC%>">立刻游戏</a><br/>
	2007年最强劲的手机网络游戏《仙道》邀请您免费试玩！<br/>
	<a href="<%=reg_url%>?from=4&amp;<%=paraStringESC%>">成仙从魔</a><br/>
	两大阵营，六大职业，无限互杀，等你加入!<br/>
	剑仙|羽士|诛仙|狂妖|巫妖|影鬼<br/>
	<a href="<%=reg_url%>?from=5&amp;<%=paraStringESC%>">选择职业</a><br/>
	万年之后，第二次仙魔大战已经拉开帷幕！仙魔大战邀您参加！<br/>
	<a href="<%=reg_url%>?from=6&amp;<%=paraStringESC%>">进入仙界大战</a><br/>
	神兵利器！谁与争锋<br/>
	<img src="images/lietian.png" alt="猎天"/><img src="images/xiushang.png" alt="秀殇"/><br/>
	<a href="<%=reg_url%>?from=7&amp;<%=paraStringESC%>">开始游戏</a><br/>
</small>
----------<br/><%@include file="push.inc"%>                                                         
狗狗娱乐独家运营<br/><%
java.text.SimpleDateFormat formatternow = new java.text.SimpleDateFormat("HH:mm");
java.util.Date currentTime_now = new java.util.Date();
String dateStringnow = formatternow.format(currentTime_now);
out.print(dateStringnow);%>
</p>
</card>
</wml>
