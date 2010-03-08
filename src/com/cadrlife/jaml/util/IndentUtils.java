package com.cadrlife.jaml.util;

import com.google.common.base.CharMatcher;

public class IndentUtils {
	public static String indent(String text, int amount) {
		String current = spaces(baseIndentation(text));
		String textWithoutFirstIndent = CharMatcher.is(' ').trimLeadingFrom(text);
		String target = spaces(amount);
		return target + textWithoutFirstIndent.replaceAll("\n"+current, "\n"+target ); 
	}
	
	public static String spaces(int spaces) {
		String string = "";
		for (int i = 0; i<spaces; i++) {
			string += " ";
		}
		return string;
	}

	public static int baseIndentation(String text) {
		return text.length() - CharMatcher.is(' ').trimLeadingFrom(text).length();
	}

	public static boolean containsNesting(String text) {
		return text.contains("\n" + spaces(baseIndentation(text)+1));
	}

	public static boolean hasContentOnFirstLine(String text) {
		int endOfFirstLine = text.contains("\n") ? text.indexOf('\n') : text.length();
		return !text.substring(0, endOfFirstLine).trim().isEmpty();
	}
}