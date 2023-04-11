/*
 *  The scanner definition for COOL.
 */
%option noyywrap
/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Dont remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
    YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
#define ERROR_AND_INITIAL \
    BEGIN(INITIAL); \
    return ERROR;
#define CHK_STR_LEN \
    if(string_buf_ptr - string_buf >= MAX_STR_CONST) \
    {   \
        cool_yylval.error_msg = "String constant too long"; \
        char ch; \
        while((ch=yyinput()) != '\"' && ch != EOF) \
            continue; \
        ERROR_AND_INITIAL \
    }
int quote_comment_num = 0;

%}

%x QUOTE_COMMENT
%x DASH_COMMENT
%x STRING

/* Define names for regular expressions here. */
CLASS     (?i:class)
ELSE      (?i:else)
FI        (?i:fi)
IF        (?i:if)
IN        (?i:in)
INHERITS  (?i:inherits)
LET       (?i:let)
LOOP      (?i:loop)
POOL      (?i:pool)
THEN      (?i:then)
WHILE     (?i:while)
CASE      (?i:case)
ESAC      (?i:esac)
OF        (?i:of)
NEW       (?i:new)
ISVOID    (?i:isvoid)
NOT       (?i:not)
TRUE      (t(?i:rue))
FALSE     (f(?i:alse))

DIGIT     [0-9]
INT       {DIGIT}+
LETTER    [a-zA-Z]
ID        ({LETTER}|{DIGIT}|_)
TYPEID    [A-Z]{ID}*
OBJID     [a-z]{ID}*

WHITESPACE  [\ \t\b\f\r\v]*
SINGLE_OPERATOR      [\<\=\+/\-\*\.~\,;\:\(\)@\{\}]


%% 

 /*
  *  Nested comments
  */
'--'                        { BEGIN(DASH_COMMENT); }
<DASH_COMMENT>.             {}
<DASH_COMMENT><<EOF>>       { BEGIN(INITIAL); }
<DASH_COMMENT>\n            { BEGIN(INITIAL); curr_lineno++; }

"(*"                        { BEGIN(QUOTE_COMMENT); quote_comment_num = 1;}
<QUOTE_COMMENT>"(*"         { quote_comment_num++; }
<QUOTE_COMMENT>"*)"         { 
    if(--quote_comment_num == 0)
        BEGIN(INITIAL);
    else
    {
        cool_yylval.error_msg = "Unmatched *)";
        ERROR_AND_INITIAL
}}
<QUOTE_COMMENT><<EOF>>      {
  cool_yylval.error_msg = "EOF in comment"; 
  ERROR_AND_INITIAL
}

<QUOTE_COMMENT>\n           { curr_lineno++; }
<QUOTE_COMMENT>.            {}

"*)"                        {
    cool_yylval.error_msg = "Unmatched *)";
    ERROR_AND_INITIAL
}

{WHITESPACE}        {}


 /*
  *  The multiple-character operators.
  */
"=>"		{ return (DARROW); }
"<-"		{ return (ASSIGN); }
"<="        { return LE; }

{SINGLE_OPERATOR}       { return *yytext; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

{CLASS}     { return CLASS; }
{FI}        { return FI;    }
{IF}        { return IF;    }
{ELSE}      { return ELSE;  }
{IN}        { return IN;    }
{INHERITS}  { return INHERITS;}
{LET}       { return LET;   }
{LOOP}      { return LOOP;  }
{POOL}      { return POOL;  }
{THEN}      { return THEN;  }
{WHILE}     { return WHILE; }
{CASE}      { return CASE;  }
{ESAC}      { return ESAC;  }
{OF}        { return OF;    }
{NEW}       { return NEW;   }
{ISVOID}    { return ISVOID;}
{NOT}       { return NOT;   }
{NOT}	    { return NOT;   }
{TRUE}  {
    cool_yylval.boolean = true;
    return BOOL_CONST;
}
{FALSE} {
    cool_yylval.boolean = false;
    return BOOL_CONST;
}

 /*
  * Identifiers
  */
{TYPEID}    {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}
{OBJID}  {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}
{INT}   {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
\"      {
    string_buf_ptr = string_buf;
    BEGIN(STRING);
}
<STRING>\\[^0]     {
    char ch = yytext[1];
    switch(ch)
    {   case 't': *string_buf_ptr++ = '\t'; break;
        case 'b': *string_buf_ptr++ = '\b'; break;
        case 'f': *string_buf_ptr++ = '\f'; break;
        default : *string_buf_ptr++ = ch;
    }
    CHK_STR_LEN
}
<STRING>\"        {
    BEGIN(INITIAL);
    *string_buf_ptr++ = '\0';
    cool_yylval.symbol = stringtable.add_string(string_buf);
    /* The parameter can't be string_buf_ptr, because it is the end of string array. */
    return STR_CONST;
}
<STRING><<EOF>>     {
    cool_yylval.error_msg = "EOF in string constant";
    ERROR_AND_INITIAL
}
<STRING>\\\n        {
    *string_buf_ptr++ = '\n';
    curr_lineno++;
    CHK_STR_LEN
}

<STRING>\n          {
    cool_yylval.error_msg = "Unterminated string constant";
    curr_lineno++;
    ERROR_AND_INITIAL
}

<STRING>\\0        {
    char ch;
    char isEscaped = false;
    while((ch = yyinput()) != '\n' && ch != EOF)
    {
        if (ch == '\"')
        {
        isEscaped = true;
        break;
        }
    }
    if (isEscaped)
        cool_yylval.error_msg = "String contains escaped null character.";
    else 
        cool_yylval.error_msg = "String contains null character.";
    
    ERROR_AND_INITIAL
}

<STRING>.           {
    *string_buf_ptr++ = *yytext;
    CHK_STR_LEN
}

\n      {
    curr_lineno++;
}

\\      {
    cool_yylval.error_msg = "Undefined backslash";
    return ERROR;
}

.       {
    cool_yylval.error_msg = strdup(yytext);
    return ERROR;
}

%%
