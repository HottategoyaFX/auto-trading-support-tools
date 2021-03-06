//+------------------------------------------------------------------+
//| MetaTraderの外からの監視を可能にするために口座への接続とEAの情報をファイルに書き出すEA
//| メールでポジション情報を通知することもできます。
//| 
//| TerminalMonitoring.mq4
//+------------------------------------------------------------------+
#property copyright "Copyright (C) 2019 Teruhiko Kusunoki."
#property link "http://www.terukusu.org/" 

#include <stdlib.mqh>

// モニタリング間隔(秒数)
extern int INTERVAL=15;
extern string MAIL_SUBJECT="MetaTrader Monitoring";

// EA名とmagicのマッピング(magic_01〜magic_05の５個まで設定できる)
input int magic_01=0;
input string magic_01_name="noname";

input int magic_02=0;
input string magic_02_name="noname";

input int magic_03=0;
input string magic_03_name="noname";

input int magic_04=0;
input string magic_04_name="noname";

input int magic_05=0;
input string magic_05_name="noname";
//+------------------------------------------------------------------+
//| マジックナンバーとEA名のマップ要素                                                                 |
//+------------------------------------------------------------------+
struct MagicInfo
  {
   int               magic;
   char              name[128];
  };

// 定数
const int arr_reserve=20;

//グローバル変数
MagicInfo magic_list[5];
int tickets_old[];
int tickets_now[];
int tickets_added[];
int tickets_deleted[];
int ut_old=0;
datetime last_OnTimer_exec=0;
datetime test_begin=0;
int test_tickets[5];
//+------------------------------------------------------------------+
//| OnInit                                                                 |
//+------------------------------------------------------------------+
int OnInit()
  {
   ArrayResize(tickets_old,0,arr_reserve);
   ArrayResize(tickets_now,0,arr_reserve);
   ArrayResize(tickets_added,0,arr_reserve);
   ArrayResize(tickets_deleted,0,arr_reserve);

   magic_list[0].magic=magic_01;
   StringToCharArray(magic_01_name,magic_list[0].name);

   magic_list[1].magic=magic_02;
   StringToCharArray(magic_02_name,magic_list[1].name);

   magic_list[2].magic=magic_03;
   StringToCharArray(magic_03_name,magic_list[2].name);

   magic_list[3].magic=magic_04;
   StringToCharArray(magic_04_name,magic_list[3].name);

   magic_list[4].magic=magic_05;
   StringToCharArray(magic_05_name,magic_list[4].name);

   if(IsTesting())
     {
      test_begin=TimeCurrent();
      ArrayInitialize(test_tickets,0);
     }

   EventSetTimer(INTERVAL);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
  }
//+------------------------------------------------------------------+
//| OnTimer
//+------------------------------------------------------------------+
void OnTimer()
  {
   PerformMonitoring();
  }
//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(IsTesting())
     {
      if(TimeCurrent()-last_OnTimer_exec>INTERVAL)
        {
         OnTimer();
         last_OnTimer_exec=TimeCurrent();
        }

      TestSenario();
     }
  }
//+------------------------------------------------------------------+
//| PerformMonitoring                                                |
//+------------------------------------------------------------------+
void PerformMonitoring()
  {
   int i,ticket,num_added,num_deleted;

   ArrayResize(tickets_now,0,arr_reserve);
   ArrayResize(tickets_added,0,arr_reserve);
   ArrayResize(tickets_deleted,0,arr_reserve);

   long nowlocal_ut=TimeLocal();
   int filehandle;

//ハートビートファイルの更新
   filehandle=FileOpen("terminal_monitoring.csv",FILE_READ|FILE_WRITE|FILE_TXT,0,CP_UTF8);

   if(filehandle!=INVALID_HANDLE)
     {
      //Print("FileOpene Finish");
      FileSeek(filehandle,0,SEEK_END);
      FileWriteString(filehandle,(string)TimeGMT()+",");
      FileWriteString(filehandle,(string)TimeCurrent()+",");
      FileWriteString(filehandle,(string)Bid+",");
      FileWriteString(filehandle,(string)Ask+",");
      FileWriteString(filehandle,(string)MarketInfo(Symbol(),MODE_SPREAD)+",");
      FileWriteString(filehandle,(string)TerminalInfoInteger(TERMINAL_PING_LAST)+",");
      FileWriteString(filehandle,DoubleToStr(pricePerPip(),4)+",");
      FileWriteString(filehandle,Symbol()+"\n");
      FileClose(filehandle);
      //Print("FileWriteString Finish");
     }
   else Print("Operation FileOpen failed, error ",GetLastError());

//現在のチケットを取得する
   for(i=0; i<OrdersTotal(); i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      ticket=OrderTicket();
      push(tickets_now,ticket);

      if(!in_array(tickets_old,ticket))
        {
         push(tickets_added,ticket);
        }
     }
//削除されたポジションのチェック
   for(i=0; i<ArraySize(tickets_old); i++)
     {
      ticket=tickets_old[i];
      if(!in_array(tickets_now,ticket))
        {
         push(tickets_deleted,ticket);
        }
     }
// ポジションに変化があった場合の処理
   num_added=ArraySize(tickets_added);
   num_deleted=ArraySize(tickets_deleted);
   string msg="";

   for(i=0; i<num_added; i++)
     {
      ticket=tickets_added[i];
      if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) continue;

      msg = msg + magic2eaname(OrderMagicNumber()) + " ";
      msg = msg + "新規 #" + (string)OrderTicket() + " ";
      msg = msg + ordertype2str(OrderType()) + " " + DoubleToStr(OrderLots(),2) + " ";
      msg = msg + OrderSymbol() + ", 価格 " + dts2(OrderOpenPrice()) + " ";
      msg = msg + "sl: " + dts2(OrderStopLoss()) + " ";
      msg = msg + "tp: " + dts2(OrderTakeProfit()) + ", ";
      msg = msg + "他: " + (string)(OrdersTotal() - 1) + "\n";
     }

   for(i=0; i<num_deleted; i++)
     {
      ticket=tickets_deleted[i];
      if(ticket==0) break;
      if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY)) continue;

      msg = msg + magic2eaname(OrderMagicNumber()) + " ";
      msg = msg + "決済 #" + (string)OrderTicket() + " ";
      msg = msg + ordertype2str(OrderType()) + " " + DoubleToStr(OrderLots(),2) + " ";
      msg = msg + OrderSymbol() + " 価格 " + dts2(OrderOpenPrice()) + " ";
      msg = msg + "→ " + dts2(OrderClosePrice()) + ", ";
      msg = msg + "損益: " + DoubleToStr(OrderProfit(),2) + " ";
      msg = msg + "口座残高: " + DoubleToStr(AccountBalance(),2) + " " + AccountCurrency() + ", ";
      msg = msg + "他: " + (string)(OrdersTotal()) + "\n";
     }
//Print("msg="+msg);

   if(StringLen(msg)>0)
     {
      //メール送信
      if(TerminalInfoInteger(TERMINAL_EMAIL_ENABLED) && StringLen(MAIL_SUBJECT))
        {
         SendMail(MAIL_SUBJECT,msg);
        }

      // 外部の監視系のためにオーダー情報を書き出す。ファイル削除は外部に任せてここでは追記するのみ。
      //Print("FileOpening..");
      filehandle=FileOpen("order_status",FILE_READ|FILE_WRITE|FILE_TXT,';',CP_UTF8);
      if(filehandle!=INVALID_HANDLE)
        {
         //Print("FileOpene Finish");
         FileSeek(filehandle,0,SEEK_END);
         FileWriteString(filehandle,msg);
         FileClose(filehandle);
         //Print("FileWriteString Finish");
        }
      else Print("Operation FileOpen failed, error ",GetLastError());
     }

//現在のチケット番号とチェック時間を保存する
   ArrayResize(tickets_old,ArraySize(tickets_now),arr_reserve);
   for(i=0; i<ArraySize(tickets_now); i++) tickets_old[i]=tickets_now[i];
   ut_old=nowlocal_ut;
  }
//小数点を適切に切る
string dts2(double val)
  {
   if(val < 10) return(DoubleToStr(val,4));
   else return(DoubleToStr(val,2));
  }
//+------------------------------------------------------------------+
//| 現在の通貨ペアの1pipあたりの値を取得します                                                |
//+------------------------------------------------------------------+
double pricePerPip()
  {
   int digits=Digits();

   if(digits<=3)
     {
      return(0.01);
     }
   else if(digits>=4)
     {
      return(0.0001);
     }
   else return(0);
  }
//OrderTypeの値を文字列で返す
string ordertype2str(int type)
  {
   if(type == OP_BUY)            return("BUY");
   else if(type == OP_SELL)      return("SELL");
   else if(type == OP_BUYLIMIT)  return("BUYLIMIT");
   else if(type == OP_SELLLIMIT) return("SELLLIMIT");
   else if(type == OP_BUYSTOP)   return("BUYSTOP");
   else if(type == OP_SELLSTOP)  return("SELLSTOP");
   else return("unknown");
  }
//配列の最後に値を追加する
int push(int &ary[],int val)
  {
   int len=ArraySize(ary);
   ArrayResize(ary,(len+1),arr_reserve);
   ary[len]=val;
   return(ArraySize(ary));
  }
//配列内に指定した値が存在するか
bool in_array(int &ary[],int val)
  {
   bool res = false;
   for(int i=0; i<ArraySize(ary); i++)
     {
      if(ary[i]==val)
        {
         res=true;
         break;
        }
     }
   return(res);
  }
//マジックナンバーからEA名を取得する
string magic2eaname(int magic)
  {
   MagicInfo info;

   if(magic == 0) return("N/A");

   info=FindMagic(magic);
   if(info.magic != 0) return CharArrayToString(info.name);

   return("EA" + DoubleToStr(magic,0));
  }
//+------------------------------------------------------------------+
//| マジックナンバーからEA情報を取得します                                                                 |
//+------------------------------------------------------------------+
MagicInfo FindMagic(int magic)
  {
   MagicInfo result;
   result.magic=0;
   result.name[0]=0;
   if(magic==0)
     {
      return result;
     }

   for(int i=0; i<ArraySize(magic_list); i++)
     {
      if(magic_list[i].magic==magic)
        {
         result=magic_list[i];
         break;
        }
     }

   return result;
  }
//+-------------- ここから下はストラテジテスターで使う関数 ------------------------+
//+------------------------------------------------------------------+
//| テスト用の売買シナリオ                                                                 |
//+------------------------------------------------------------------+
void TestSenario()
  {
   int result;

   if(TimeCurrent()-test_begin>30)
     {
      if(test_tickets[0]==0)
        {
         result=TestOrderSend();
         if(result)
           {
            test_tickets[0]=result;
           }
        }
     }

   if(TimeCurrent()-test_begin>60)
     {
      if(test_tickets[0]>0)
        {
         if(TestOrderClose(test_tickets[0]))
           {
            test_tickets[0]=-test_tickets[0];
           }
        }
     }
   if(TimeCurrent()-test_begin>90)
     {
      if(test_tickets[1]==0)
        {
         result=TestOrderSend();
         if(result)
           {
            test_tickets[1]=result;
           }
        }
      if(test_tickets[2]==0)
        {
         result=TestOrderSend();
         if(result)
           {
            test_tickets[2]=result;
           }
        }
     }

   if(TimeCurrent()-test_begin>120)
     {
      if(test_tickets[1]>0)
        {
         if(TestOrderClose(test_tickets[1]))
           {
            test_tickets[1]=-test_tickets[1];
           }
        }
      if(test_tickets[2]>0)
        {
         if(TestOrderClose(test_tickets[2]))
           {
            test_tickets[2]=-test_tickets[2];
           }
        }
     }

   if(TimeCurrent()-test_begin>150)
     {
      if(test_tickets[3]==0)
        {
         result=TestOrderSend();
         if(result)
           {
            test_tickets[3]=result;
           }
        }
     }
   if(TimeCurrent()-test_begin>180)
     {
      if(test_tickets[4]==0)
        {
         result=TestOrderSend();
         if(result)
           {
            test_tickets[4]=result;
           }
        }
     }
   if(TimeCurrent()-test_begin>210)
     {
      if(test_tickets[3]>0)
        {
         if(TestOrderClose(test_tickets[3]))
           {
            test_tickets[3]=-test_tickets[3];
           }
        }
     }
   if(TimeCurrent()-test_begin>240)
     {
      if(test_tickets[4]>0)
        {
         if(TestOrderClose(test_tickets[4]))
           {
            test_tickets[4]=-test_tickets[4];
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| テスト用： 決済                                                                 |
//+------------------------------------------------------------------+
bool TestOrderClose(int ticket)
  {
   int result;
   result=OrderSelect(ticket,SELECT_BY_TICKET);
   if(!result)
     {
      Print("Order select error ",GetLastError());
      return false;
     }
   result=OrderClose(OrderTicket(),OrderLots(),Bid,3,White);
   if(!result)
     {
      Print("Order close error ",GetLastError());
      return false;
     }

   return true;
  }
//+------------------------------------------------------------------+
//| テスト用： オーダーオープン                                                                 |
//+------------------------------------------------------------------+
int TestOrderSend()
  {
   int result;
   result=OrderSend(Symbol(),OP_BUY,0.1,Ask,30,NULL,NULL,"Buy",123,0,Blue);
   if(!result)
     {
      Print("Order open error ",GetLastError());
      return 0;
     }

   return result;
  }
//+------------------------------------------------------------------+
