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
<card id="readme">
    <%
	String from= (String)request.getParameter("from");
    %>
    <p>
    **仙道世界**<br/>
    =仙道注册服务条款=<br/>
    </p>
    <p>
    1.此注册服务条款描述仙道网游向用户提供的详细服务条款.请于注册前详细阅读本服务条款的所有内容,当用户开始仙道网游即被视为同意并接受本服务条款的所有规范并愿受其约束.如果发生纠纷,用户不得以未仔细阅读为由实行抗辩.<br/>
    2.仙道网游不承担以下的费用支出：
    2.1用户登入仙道网游所产生的GPRS流量上网费.
    2.2使用收费游戏功能等（仙道网游会注释表明，提供用户使用选择权）<br/>
    3.当网络发生下列情形之时，仙道网游不承担任何责任:
    3.1对于仙道网游的网络设备进行必要的保养及施工
    3.2由于仙道网游所用的网络通信设备由于不明原因或突发性的网络设备停止而无法提供网络服务. 
    3.3由于外界不可抗力因素致而无法提供网络服务.
    3.4由于相关政府机构政策要求.<br/>
    4.凡用户有以下违规行为,仙道网游有权取消该用户的游戏账号:
    4.1有通过非手机方式上网游戏的行为. 
    4.2有损害其他用户利益的行为. 
    4.3有违反官方游戏规定的行为.
    4.4有违法国家宪法法律法规的行为. 
    4.5有其他违反本协议约定的行为.<br/>
    仙道网游保留随时修改本服务条款的权利,以上条款的最终解释权归仙道网游所有. <br/>
    </p>
    <p>
	<%
	if(from == ""){
		out.print("<a href=\"./index.jsp?"+paraStringESC+"\">返回</a><br/>");
	}
	else{
		out.print("<a href=\"./regnew.jsp?"+paraStringESC+"\">返回</a><br/>");
	}
	%>
   	<a href="./index.jsp">[返回首页]</a><br/>
	成仙从魔一念间<br/>
	<a href="http://wap.dogstart.com">dogstart.com</a><br/>
 	--------<br/>
	<%
    	java.text.SimpleDateFormat formatternow = new java.text.SimpleDateFormat("HH:mm");
        java.util.Date currentTime_now = new java.util.Date();
    	String dateStringnow = formatternow.format(currentTime_now);
        out.println(dateStringnow);
	%>
 </p>
</card>
</wml>
