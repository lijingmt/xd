<%@ page import="org.apache.log4j.*"%>                                             
<%!
public String ip="127.0.0.1";
public int port=5400;
public String projname="gamelib";
public String gamename="xiand00";
public String game_pre="xd00";
public String gamename_cn="仙道II测试00";
public String index_url="http://work.dogstart.com/xiand00/index.jsp";
public String internet_addr="xdx.tx.com.cn"; //游戏服务器域名
public String internet_ip="222.73.44.147";   //游戏服务器ip
public String our_ip = "124.126.87.8";
public int game_close = 1;        //游戏是否对外关闭的标志位，设置该标示位为1时，只有ip为"our_ip"的用户可以访问
static Logger loggerSpread = Logger.getLogger("com.ldwy.xdSpread");
static Logger logger = Logger.getLogger("com.ldwy.xdpv");
static Logger logger_pv = Logger.getLogger("com.ldwy.xdpv");
%>
