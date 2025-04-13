<!DOCTYPE html>
<html>
<head>
	<%@ page language="java" contentType="text/html;charset=UTF-8"%>
	<%@include file="includes/header.inc"%> 
	<meta charset="UTF-8">
	<meta name="viewport" content="maximum-scale=1.0,minimum-scale=1.0,user-scalable=0,width=device-width,initial-scale=1.0"/>
<title>天下仙道网游[一区]</title>
<link href="includes/intro.css" rel="stylesheet" type="text/css"/>
</head>
<body>

<div>
	<!DOCTYPE html>
	<html lang="zh-cn">
		<head>
			<meta charset="UTF-8">
			<meta name="viewport" content="maximum-scale=1.0,minimum-scale=1.0,user-scalable=0,width=device-width,initial-scale=1.0"/>
			<title>天下仙道网游[一区]</title>
			<link href="includes/bootstrap.min.css" rel="stylesheet">
			<style>
				body {
					font: Normal 18px "Arial Black";
					text-align: center;
				}
				@media (min-width: 768px) {
					body {
						margin: 0 auto;
						width: 414px;
					}
				}
				.logo {
					margin-top: 5px;
					width: 240px;
					height: 64px;
				}
				.form-group{
					width:90%;
					margin:5%;
				}
				.lable{
					width:60px;
					font-size: 16px;
					font-weight: 500;
					text-align: center;
				}
				.input{
					width:calc(100% - 80px);
					font-size: 16px;
				}
				.desc{
					width: 90%;
					margin: 5%;
				}
				.copyright{
					margin-top:30px;
				}
				.btns{
					margin-top:30px;
				}
				.btn{
					margin: 0 20px;
				}
				h2{
					font-size:20px;
				}
			</style>
		</head>
	<body>

			<img src="../logo.gif" class="logo">

			
<%
  String user = request.getParameter("usid");
  String pswd = request.getParameter("pswd");
  String g_key = "";
  g_key=user+"|"+pswd;
  
  long ot = System.currentTimeMillis();
  string m_key=String.valueOf(ot);
  
  if( user==null || pswd==null )
  	response.sendRedirect("./pc.jsp?err=1");
  else{
	user = user.trim();
	pswd = pswd.trim();
	if(user.length() == 0 || pswd.length() == 0)
  		response.sendRedirect("./pc.jsp?err=1");//字符为空
	else if( user.length()<2 || pswd.length()<2 )
  		response.sendRedirect("./pc.jsp?err=2");//字符小于2位
	else if( user.length()>13 || pswd.length()>13 )
  		response.sendRedirect("./pc.jsp?err=3");//字符大于10位
	else{
		String user_pswd = user + pswd;
		if(!isLegalChar(user_pswd))
  			response.sendRedirect("./pc.jsp?err=4");//非法字符
		else{
			//帐号检测	
			String strcheck = "";
			Socket socket = new Socket(ip,port);
			InputStream reader = socket.getInputStream();
			OutputStream writer = socket.getOutputStream();
			String sid1 = (String)session.getId();
			send(writer,("login_check_p "+area+""+user +" "+area).getBytes());
			send(writer,"flush_filter".getBytes());
			socket.shutdownOutput();

			strcheck = read(reader,"utf-8");

			if(writer!=null) writer.close();
			if(reader!=null) reader.close();
			if(socket!=null) socket.close();
	
			//有档案帐号存在,login_des直接跳转登录
			if(strcheck.equals("yes")){
				Socket socket1 = new Socket(ip,port);
				InputStream reader1 = socket1.getInputStream();
				OutputStream writer1 = socket1.getOutputStream();
				String sid2 = (String)session.getId();
				send(writer1,("login_entrycheck_p "+projname+" "+area+""+user+" "+pswd+" "+sid2).getBytes());
				send(writer1,"flush_filter".getBytes());
				socket1.shutdownOutput();

				String ret = read(reader1,"utf-8");

				if(writer1!=null) writer1.close();
				if(reader1!=null) reader1.close();
				if(socket1!=null) socket1.close();
				
				String resultData = "<h2>验证成功</h2>";
				resultData += "<h4 class=\"desc\">帐号："+user+"</h4>";
				resultData += "<h4 class=\"desc\">密码："+pswd+"</h4>";
			   																				  //response.sendRedirect("./main.jsp?_user="+user_new+"&_pswd="+pswd+"&regnewFlag="+regnewFlag+"&game_fg="+game_fg);   
				resultData += "<a class=\"btn btn-danger btn-lg\" style=\"margin-top:10px;\" href=\""+internet_addr+"/xd/game.jsp?info="+ret+"\">进入游戏</a>";
				resultData += "<h4 class=\"text-success\">最新通告(2022-02-22)</h4>";
				resultData += "<h5 class=\"text-success\">1.充值就送大礼！(详情参见游戏内说明)</h5>";
				resultData += "<h5 class=\"text-success\">2.日常技能任务开放，不用辛苦刷技能经验了！</h5>";
				resultData += "<h5 class=\"text-success\">3.节前开放一批新宝库、声望装备！boss也会掉噢！</h5>";
				out.println(resultData);
			}else{
				//无帐号，login_regnew注册并登录
				Socket socket2 = new Socket(ip,port);
				InputStream reader2 = socket2.getInputStream();
				OutputStream writer2 = socket2.getOutputStream();

				String sid3 = (String)session.getId();

				send(writer2,("login_regnew_p "+projname+" "+user+" "+pswd+" "+sid3+" "+area).getBytes());
				send(writer2,"flush_filter".getBytes());
				socket2.shutdownOutput();

				String ret = read(reader2,"utf-8");

				if(writer2!=null) writer2.close();
				if(reader2!=null) reader2.close();
				if(socket2!=null) socket2.close();
			
				String resultData = "<h2>注册成功</h2>";
				
				int i=0;
				for(i=0;i<ret.length()&&ret.charAt(i)!=',';i++)
					;
				if(i!=ret.length())
				{
					stru = ret.substring(0,i);
					strp = ret.substring(i+1,ret.length());
				}
				
				resultData += "<h4 class=\"desc\">帐号："+stru+"</h4>";
				resultData += "<h4 class=\"desc\">密码："+strp+"</h4>";
																			 //out.print("<a href=\"./main.jsp?_user="+game_pre+user+"&amp;_pswd="+pswd+"&amp;_sid="+sid+"&amp;_mkey="+m_key+"&amp;_reg=1&amp;game_fg="+game_pre+"\">play game now</a><br/>");
				resultData += "<a class=\"btn btn-danger btn-lg\" style=\"margin-top:10px;\" href=\""+internet_addr+"/xd/game.jsp?_user="+area+user+"&amp;_pswd="+pswd+"&amp;_sid="+sid3+"&amp;_mkey="+m_key+"&amp;_reg=1&amp;game_fg="+area+"\">进入游戏</a>";
				resultData += "<h4 class=\"text-success\">最新通告(2022-02-22)</h4>";
				resultData += "<h5 class=\"text-success\">1.充值就送大礼！(详情参见游戏内说明)</h5>";
				resultData += "<h5 class=\"text-success\">2.日常技能任务开放，不用辛苦刷技能经验了！</h5>";
				resultData += "<h5 class=\"text-success\">3.节前开放一批新宝库、声望装备！boss也会掉噢！</h5>";
				out.println(resultData);
			
			}
		}
	}
  }
%>
		<br/>
		<h6 class="text-danger">本游戏仅在非中国地区运营，请遵守本地法律使用本游戏服务<br/></h6>
		<h6 class="text-danger">版权所有 2022  天下团队 地点日本美国<br/></h6>
		<br/>
		<h4 class="copyright">© 2022 《天下仙道网游》<br/><br/><a href="./pc.jsp">返回首页</a></h4>
			</body>
			<script src="includes/jquery.min.js"></script>
			<script src="includes/bootstrap.min.js"></script>
			</html>

</body>
</html>
