grammar Jaml;

options {
  output=AST;
  ASTLabelType=CommonTree; // type of $stat.tree ref etc...
}

tokens {
  INDENT;
  DEDENT;
  NEWLINE;
}

@parser::header {
package com.cadrlife.jaml;
import java.util.LinkedHashMap;
import java.util.Map;
}

@lexer::header {
package com.cadrlife.jaml;
}


@lexer::members {
	int currentIndentation = 0;
	boolean textMode = true;
	boolean hashMode = false;
	boolean beginningOfLine = true;
	int braceDepth = 0;
	
	List tokens = new ArrayList();
	@Override
	public void emit(Token token) {
	        state.token = token;
	    	tokens.add(token);
	}
	@Override
	public Token nextToken() {
	    	super.nextToken();
	        if ( tokens.size()==0 ) {
	            return Token.EOF_TOKEN;
	        }
	        return (Token)tokens.remove(0);
	}
}

@parser::members {
String output = "";
JamlConfig config = new JamlConfig();
Helper util = new Helper(config);
}

jamlSource[JamlConfig config] returns [String rendering]
@init {
  $rendering = ""; 
  this.config = $config;
  Helper util = new Helper(config);
}
: (line {$rendering += $line.rendering;} {$rendering += "\n";})*;

element returns [String rendering] @init {String content = ""; boolean selfClosing=false;}:
  elementDeclaration 
   ( freeformText NEWLINE {content = $freeformText.rendering;} | 
     NEWLINE (content {content = $content.rendering;})? |
     FORWARD_SLASH NEWLINE {selfClosing = true;})
  {$rendering = util.elem($elementDeclaration.type, $elementDeclaration.attrMap, content, selfClosing);}
  ;

line returns [String rendering] @init { $rendering = ""; } :
  element {$rendering = $element.rendering;}
  | freeformText {$rendering = $freeformText.rendering;} NEWLINE
  | NEWLINE
  ;
  
freeformText returns [String rendering]:
      TEXT
      {
        $rendering = util.parseFreeFormText($TEXT.text);
      };

elementDeclaration returns [String type, Map<String,String> attrMap] 
  @init {$attrMap = new LinkedHashMap<String,String>();}:
  (a1=divAttrs[$attrMap] {$type = "div";} attrHash[$attrMap]?)
| 
 (
  a2=attrs[$attrMap] {$type = $a2.type;} 
  attrHash[$attrMap]?) 
  ;

content returns [String rendering] @init { $rendering = ""; } :
INDENT 
 (e1=element {$rendering += $e1.rendering + "\n";} | freeformText NEWLINE {$rendering += $freeformText.rendering + "\n";})+
DEDENT
{$rendering = "\n" + util.indent(util.stripTrailingNewline($rendering)) + "\n";}
;

attrs[Map<String,String> attrMap] returns [String type]:
PERCENT ID {$type = $ID.text;}
(idSpecifier {$attrMap.put("id", $idSpecifier.id);} |
 classSpecifier {$attrMap.put("class", $classSpecifier.klass);})*;

divAttrs[Map<String,String> attrMap] :
(idSpecifier {$attrMap.put("id", $idSpecifier.id);} |
 classSpecifier {$attrMap.put("class", $classSpecifier.klass);})+;

attrHash[Map<String,String> attrMap] :
  BEGIN_HASH {System.out.println("BEGIN " + $text);}
  hashAttrs 
  END_HASH {util.parseAttrHash($hashAttrs.contents, $attrMap);};

hashAttrs returns [String contents] @init {$contents="";} :
(notEndHash {$contents += $notEndHash.text;})*;

notEndHash : (~END_HASH) {System.out.println("() " + $notEndHash.text);};

idSpecifier returns [String id]: POUND ID {$id = $ID.text;};

classSpecifier returns [String klass]:
DOT ID {$klass = $ID.text;};

// LEXER

POUND: { beginningOfLine }?=> '#' {textMode = false;};
DOT: { beginningOfLine }?=> '.' {textMode = false;};
PERCENT: { beginningOfLine }?=> '%' {textMode = false;};
FORWARD_SLASH: { !hashMode }?=> '/';
COMMA: { !textMode }?=> ',';
ID  : { !textMode }?=> 
  ('a'..'z'|'A'..'Z') ('a'..'z'|'A'..'Z'|'0'..'9')*
  {textMode = true;};
// NEWLINE: ('\r'? '\n') {textMode = true; beginningOfLine=true;};

WS : { !textMode }?=>
  Spaces {if (!hashMode ) { skip(); textMode=true; }};

IGNORED_NEWLINE  : { hashMode }?=> NL ;

CHANGE_INDENT 
@init { int tb = 0; } :{ !hashMode }?=> 
	(NL) (' ' {tb++;})* {
	          emit(new CommonToken(NEWLINE));
	          System.out.println("NEWLINE");
	          System.out.println(tb + "/" + currentIndentation);
	          if (tb > currentIndentation) {
	              emit(new CommonToken(INDENT));
	              System.out.println("INDENT");
	          } else if(tb < currentIndentation) {
	              for(int i = 0; i < currentIndentation - tb; i+=2) {
	    	          emit(new CommonToken(DEDENT));
		    	      System.out.println("DEDENT");
	              }
	          } else {
	              //skip();
	          }
	          currentIndentation = tb;
	          textMode=true;
	          beginningOfLine=true;
      };
fragment
NL: '\r'? '\n';

fragment SpacesQ: (' ')*;
fragment Spaces: (' ')+;

StringLiteral: { hashMode }?=>
    '"' ( EscapeSequence | ~('\\' | '"' | '\r' | '\n' ) )* '"'
  ;

CHARLITERAL
    :   '\'' 
        (   EscapeSequence 
        |   ~( '\'' | '\\' | '\r' | '\n' )
        ) 
        '\''
    ;
    
fragment
EscapeSequence
  :   '\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
  |   UnicodeEscape
  |   OctalEscape
  ;

fragment
OctalEscape
  :   '\\' ('0'..'3') ('0'..'7') ('0'..'7')
  |   '\\' ('0'..'7') ('0'..'7')
  |   '\\' ('0'..'7')
  ;

fragment
UnicodeEscape
  :   '\\' 'u' HexDigit HexDigit HexDigit HexDigit
  ;
  
fragment
HexDigit : ('0'..'9'|'a'..'f'|'A'..'F') ;

TEXT: { textMode && !hashMode}?=>
      (~('.' | '#' | '%' | '\r' | '\n' | '{' | ' ' | '/'))
      (~('\r' | '\n'))*
      {
        beginningOfLine = false;
      };
      
HASH_CONTENTS: { hashMode }?=>
      (~('"' | '\'' | '{' | '}'));

//EQUALS  : { hashMode }?=> ;
BEGIN_HASH  : { textMode && braceDepth == 0 }?=> LBRACE {hashMode=true;};
END_HASH  : { braceDepth == 1 }?=> RBRACE {hashMode=false;};

JAVA_LBRACE : { hashMode }?=> LBRACE;
JAVA_RBRACE : { braceDepth > 1 }?=>  RBRACE;

fragment LBRACE : '{' {braceDepth++;};
fragment RBRACE  : { hashMode }?=> '}' {braceDepth--;};

// These tokens get emitted by the CHANGE_INDENTATION rule.
// They only have their own lexer rules to shut up ANTLR's warnings.
NEWLINE : {false}?=> ' ';
INDENT : {false}?=> ' ';
DEDENT : {false}?=> ' ';