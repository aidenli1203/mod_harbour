#include "hbclass.ch"

#xcommand ? <cText> => AP_RPuts( <cText> )

#define CRLF hb_OsNewLine()

extern AP_METHOD, AP_ARGS, AP_USERIP, PTRTOSTR, AP_RPUTS, AP_RRPUTS
extern AP_HEADERSINCOUNT, AP_HEADERSINKEY, AP_HEADERSINVAL
extern AP_POSTPAIRSCOUNT, AP_POSTPAIRSKEY, AP_POSTPAIRSVAL, AP_POSTPAIRS
extern AP_HEADERSOUTCOUNT, AP_HEADERSOUTSET, AP_HEADERSIN, AP_SETCONTENTTYPE
extern HB_VMPROCESSSYMBOLS, HB_VMEXECUTE

static hPP

//----------------------------------------------------------------//

function _AppMain()

   ErrorBlock( { | o | DoBreak( o ) } )

   AddPPRules()

   if File( AP_FileName() )
      Execute( MemoRead( AP_FileName() ), AP_Args() )
   else
      ErrorLevel( 404 )
   endif   

return nil

//----------------------------------------------------------------//

function AddPPRules()

   if hPP == nil
      hPP = __pp_init()
   endif

   __pp_addRule( hPP, "#xcommand ? [<explist,...>] => AP_RPuts( [<explist>] )" )
   __pp_addRule( hPP, "#xcommand ?? [<explist,...>] => AP_RRPuts( [<explist>] )" )
   __pp_addRule( hPP, "#define CRLF hb_OsNewLine()" )
   __pp_addRule( hPP, "#xcommand TEMPLATE [ USING <x> ] [ PARAMS [<v1>] [,<vn>] ] => " + ;
                      '#pragma __cstream | AP_RRPuts( InlinePrg( %s, [@<x>] [,<(v1)>][+","+<(vn)>] [, @<v1>][, @<vn>] ) )' )
   __pp_addRule( hPP, "#command ENDTEMPLATE => #pragma __endtext" )

return nil

//----------------------------------------------------------------//

function Execute( cCode, ... )

   local oHrb, uRet
   local cHBheaders := "~/harbour/include"

   cCode = __pp_process( hPP, cCode )

   oHrb = HB_CompileFromBuf( cCode, .T., "-n", "-I" + cHBheaders )
   if ! Empty( oHrb )
      uRet = hb_HrbDo( hb_HrbLoad( oHrb ), ... )
   endif

return uRet

//----------------------------------------------------------------//

function GetErrorInfo( oError )

   local cInfo := oError:operation, n
   local cCallStack := ""

   if ValType( oError:Args ) == "A"
      cInfo += "   Args:" + CRLF
      for n = 1 to Len( oError:Args )
         cInfo += "[" + Str( n, 4 ) + "] = " + ValType( oError:Args[ n ] ) + ;
                   "   " + ValToChar( oError:Args[ n ] ) + hb_OsNewLine()
      next
   endif
   
   n = 0
   while ! Empty( ProcName( n ) )
      cCallStack += "called from: " + ProcName( n ) + ", line: " + AllTrim( Str( ProcLine( n ) ) ) + "<br>" + CRLF
      n++
   end   

return "error: " + oError:Description + hb_OsNewLine() + cInfo + "<br><br>" + CRLF + ;
       cCallStack

//----------------------------------------------------------------//

static procedure DoBreak( oError )

   ? GetErrorInfo( oError )

   BREAK

//----------------------------------------------------------------//

function ValToChar( u )

   local cType := ValType( u )
   local cResult

   do case
      case cType == "C"
           cResult = u

      case cType == "D"
           cResult = DToC( u )

      case cType == "L"
           cResult = If( u, ".T.", ".F." )

      case cType == "N"
           cResult = AllTrim( Str( u ) )

      case cType == "A"
           cResult = hb_ValToExp( u )

      case cType == "P"
           cResult = "(P)" 

      case cType == "H"
           cResult = hb_ValToExp( u )

      case cType == "U"
           cResult = "nil"

      otherwise
           cResult = "type not supported yet in function ValToChar()"
   endcase

return cResult   

//----------------------------------------------------------------//

function InlinePRG( cText, oTemplate, cParams, ... )

   local nStart, nEnd, cCode, cResult

   if PCount() > 1
      oTemplate = Template()
      if PCount() > 2
         oTemplate:cParams = cParams
      endif   
   endif   

   while ( nStart := At( "<?prg", cText ) ) != 0
      nEnd  = At( "?>", SubStr( cText, nStart + 5 ) )
      cCode = SubStr( cText, nStart + 5, nEnd - 1 )
      if oTemplate != nil
         AAdd( oTemplate:aSections, cCode )
      endif   
      cText = SubStr( cText, 1, nStart - 1 ) + ( cResult := ExecInline( cCode, cParams, ... ) ) + ;
              SubStr( cText, nStart + nEnd + 6 )
      if oTemplate != nil
         AAdd( oTemplate:aResults, cResult )
      endif   
   end 
   
   if oTemplate != nil
      oTemplate:cResult = cText
   endif   
   
return cText

//----------------------------------------------------------------//

function ExecInline( cCode, cParams, ... )

   if cParams == nil
      cParams = ""
   endif   

return Execute( "function __Inline( " + cParams + " )" + HB_OsNewLine() + cCode, ... )   

//----------------------------------------------------------------//

CLASS Template

   DATA aSections INIT {}
   DATA aResults  INIT {}
   DATA cParams   
   DATA cResult

ENDCLASS

//----------------------------------------------------------------//

#pragma BEGINDUMP

#include <hbapi.h>
#include <hbvm.h>
#include <hbapiitm.h>

static void * pRequestRec, * pAPRPuts, * pAPSetContentType;
static void * pHeadersIn, * pHeadersOut, * pHeadersOutCount, * pHeadersOutSet;
static void * pHeadersInCount, * pHeadersInKey, * pHeadersInVal;
static void * pPostPairsCount, * pPostPairsKey, * pPostPairsVal;
static const char * szFileName, * szArgs, * szMethod, * szUserIP;

int hb_apache( void * _pRequestRec, void * _pAPRPuts, 
               const char * _szFileName, const char * _szArgs, const char * _szMethod, const char * _szUserIP,
               void * _pHeadersIn, void * _pHeadersOut, 
               void * _pHeadersInCount, void * _pHeadersInKey, void * _pHeadersInVal,
               void * _pPostPairsCount, void * _pPostPairsKey, void * _pPostPairsVal,
               void * _pHeadersOutCount, void * _pHeadersOutSet, void * _pAPSetContentType )
{
   pRequestRec       = _pRequestRec;
   pAPRPuts          = _pAPRPuts; 
   szFileName        = _szFileName;
   szArgs            = _szArgs;
   szMethod          = _szMethod;
   szUserIP          = _szUserIP;
   pHeadersIn        = _pHeadersIn;
   pHeadersOut       = _pHeadersOut;
   pHeadersInCount   = _pHeadersInCount;
   pHeadersInKey     = _pHeadersInKey;
   pHeadersInVal     = _pHeadersInVal;
   pPostPairsCount   = _pPostPairsCount;
   pPostPairsKey     = _pPostPairsKey;
   pPostPairsVal     = _pPostPairsVal;
   pHeadersOutCount  = _pHeadersOutCount;
   pHeadersOutSet    = _pHeadersOutSet;
   pAPSetContentType = _pAPSetContentType;
 
   hb_vmInit( HB_TRUE );
   return hb_vmQuit();
}   

typedef int ( * AP_RPUTS )( const char * s, void * r );

HB_FUNC( AP_RPUTS )
{
   AP_RPUTS ap_rputs = ( AP_RPUTS ) pAPRPuts;
   int iParams = hb_pcount(), iParam;

   ap_rputs( "<br>", pRequestRec );

   for( iParam = 1; iParam <= iParams; iParam++ )
   {
      HB_SIZE nLen;
      HB_BOOL bFreeReq;
      char * buffer = hb_itemString( hb_param( iParam, HB_IT_ANY ), &nLen, &bFreeReq );

      ap_rputs( buffer, pRequestRec );
      ap_rputs( " ", pRequestRec ); 

      if( bFreeReq )
         hb_xfree( buffer );
   }     
}

HB_FUNC( AP_RRPUTS )
{
   AP_RPUTS ap_rputs = ( AP_RPUTS ) pAPRPuts;
   int iParams = hb_pcount(), iParam;

   for( iParam = 1; iParam <= iParams; iParam++ )
   {
      HB_SIZE nLen;
      HB_BOOL bFreeReq;
      char * buffer = hb_itemString( hb_param( iParam, HB_IT_ANY ), &nLen, &bFreeReq );

      ap_rputs( buffer, pRequestRec );
      ap_rputs( " ", pRequestRec ); 

      if( bFreeReq )
         hb_xfree( buffer );
   }     
}

HB_FUNC( AP_FILENAME )
{
   hb_retc( szFileName );
}

HB_FUNC( AP_ARGS )
{
   hb_retc( szArgs );
}

HB_FUNC( AP_METHOD )
{
   hb_retc( szMethod );
}

HB_FUNC( AP_USERIP )
{
   hb_retc( szUserIP );
}

typedef int ( * HEADERS_IN_COUNT )( void );

HB_FUNC( AP_HEADERSINCOUNT )
{
   HEADERS_IN_COUNT headers_in_count = ( HEADERS_IN_COUNT ) pHeadersInCount;
   
   hb_retnl( headers_in_count() );
}   

typedef int ( * HEADERS_OUT_COUNT )( void );

HB_FUNC( AP_HEADERSOUTCOUNT )
{
   HEADERS_OUT_COUNT headers_out_count = ( HEADERS_OUT_COUNT ) pHeadersOutCount;

   hb_retnl( headers_out_count() );
}

typedef const char * ( * HEADERS_IN_KEY )( int );

HB_FUNC( AP_HEADERSINKEY )
{
   HEADERS_IN_KEY headers_in_key = ( HEADERS_IN_KEY ) pHeadersInKey;
   
   hb_retc( headers_in_key( hb_parnl( 1 ) ) );
}   

typedef const char * ( * HEADERS_IN_VAL )( int );

HB_FUNC( AP_HEADERSINVAL )
{
   HEADERS_IN_VAL headers_in_val = ( HEADERS_IN_VAL ) pHeadersInVal;
   
   hb_retc( headers_in_val( hb_parnl( 1 ) ) );
}   

typedef int ( * POST_PAIRS_COUNT )( void );

HB_FUNC( AP_POSTPAIRSCOUNT )
{
   POST_PAIRS_COUNT post_pairs_count = ( POST_PAIRS_COUNT ) pPostPairsCount;

   hb_retnl( post_pairs_count() );
}

typedef void ( * HEADERS_OUT_SET )( const char * szKey, const char * szValue );

HB_FUNC( AP_HEADERSOUTSET )
{
   HEADERS_OUT_SET headers_out_set = ( HEADERS_OUT_SET ) pHeadersOutSet;

   headers_out_set( hb_parc( 1 ), hb_parc( 2 ) );
}

typedef const char * ( * POST_PAIRS_KEY )( int );

HB_FUNC( AP_POSTPAIRSKEY )
{
   POST_PAIRS_KEY post_pairs_key = ( POST_PAIRS_KEY ) pPostPairsKey;

   hb_retc( post_pairs_key( hb_parnl( 1 ) ) );
}

typedef const char * ( * POST_PAIRS_VAL )( int );

HB_FUNC( AP_POSTPAIRSVAL )
{
   POST_PAIRS_VAL post_pairs_val = ( POST_PAIRS_VAL ) pPostPairsVal;

   hb_retc( post_pairs_val( hb_parnl( 1 ) ) );
}

HB_FUNC( PTRTOSTR )
{
   const char * * pStrs = ( const char * * ) hb_parnll( 1 );   
   
   hb_retc( * ( pStrs + hb_parnl( 2 ) ) );
}

HB_FUNC( AP_HEADERSIN )
{
   PHB_ITEM hHeadersIn = hb_hashNew( NULL ); 
   HEADERS_IN_COUNT headers_in_count = ( HEADERS_IN_COUNT ) pHeadersInCount;
   int iKeys = headers_in_count();

   if( iKeys > 0 )
   {
      int iKey;
      PHB_ITEM pKey = hb_itemNew( NULL );
      PHB_ITEM pValue = hb_itemNew( NULL );   
      HEADERS_IN_KEY headers_in_key = ( HEADERS_IN_KEY ) pHeadersInKey;
      HEADERS_IN_VAL headers_in_val = ( HEADERS_IN_VAL ) pHeadersInVal;

      hb_hashPreallocate( hHeadersIn, iKeys );
   
      for( iKey = 0; iKey < iKeys; iKey++ )
      {
         hb_itemPutCConst( pKey,   headers_in_key( iKey ) );
         hb_itemPutCConst( pValue, headers_in_val( iKey ) );
         hb_hashAdd( hHeadersIn, pKey, pValue );
      }
      
      hb_itemRelease( pKey );
      hb_itemRelease( pValue );
   }  
   
   hb_itemReturnRelease( hHeadersIn );
}

HB_FUNC( AP_POSTPAIRS )
{
   PHB_ITEM hPostPairs = hb_hashNew( NULL ); 
   POST_PAIRS_COUNT post_pairs_count = ( POST_PAIRS_COUNT ) pPostPairsCount;
   int iKeys = post_pairs_count();

   if( iKeys > 0 )
   {
      int iKey;
      PHB_ITEM pKey = hb_itemNew( NULL );
      PHB_ITEM pValue = hb_itemNew( NULL );   
      POST_PAIRS_KEY post_pairs_key = ( POST_PAIRS_KEY ) pPostPairsKey;
      POST_PAIRS_VAL post_pairs_val = ( POST_PAIRS_VAL ) pPostPairsVal;

      hb_hashPreallocate( hPostPairs, iKeys );
   
      for( iKey = 0; iKey < iKeys; iKey++ )
      {
         hb_itemPutCConst( pKey,   post_pairs_key( iKey ) );
         hb_itemPutCConst( pValue, post_pairs_val( iKey ) );
         hb_hashAdd( hPostPairs, pKey, pValue );
      }
      
      hb_itemRelease( pKey );
      hb_itemRelease( pValue );
   }  
   
   hb_itemReturnRelease( hPostPairs );
}

typedef void ( * AP_SET_CONTENTTYPE )( const char * szContentType );

HB_FUNC( AP_SETCONTENTTYPE )
{
   AP_SET_CONTENTTYPE ap_set_contenttype = ( AP_SET_CONTENTTYPE ) pAPSetContentType;

   ap_set_contenttype( hb_parc( 1 ) );
}

HB_FUNC( HB_VMPROCESSSYMBOLS )
{
   hb_retnll( ( HB_LONGLONG ) hb_vmProcessSymbols );
}   

HB_FUNC( HB_VMEXECUTE )
{
   hb_retnll( ( HB_LONGLONG ) hb_vmExecute );
}   

#pragma ENDDUMP