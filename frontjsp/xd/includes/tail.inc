    当前时间:<%
    java.text.SimpleDateFormat formatternow = new java.text.SimpleDateFormat("HH:mm");
    java.util.Date currentTime_now = new java.util.Date();
    String dateStringnow = formatternow.format(currentTime_now);
    out.print(dateStringnow);
    out.print("<br/>"); 
    //out.print("<a href=\"http://gamepie.i139.cn/wap/s.do?j=3channel\">游戏频道</a><br/>");
    //out.print("<a href=\"http://wap.monternet.com\">梦网首页</a><br/>");
    
    %>
