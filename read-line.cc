/*
 * CS252: Systems Programming
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */


#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <cstring>
#include <string>
#include <cstdio>
#include <cstdlib>
#include <vector>
//#include "tty-raw-mode.c"

#define MAX_BUFFER_LINE 2048

extern "C" void tty_raw_mode(void);
extern "C" void tty_get_old(void);
extern "C" void tty_term_mode(void);

// Buffer where line is stored
int line_length;
//char line_buffer[MAX_BUFFER_LINE];
std::string line_buffer = "";
//Keeps track of the cursor
int cursor;
//For moving the cursor
const char *left = "\033[D";
const char *right = "\033[C";

// Simple history array
// This history does not change. 
// Yours have to be updated.
/*int history_index = 0;
char * history [] = {
  "ls -al | grep x", 
  "ps -e",
  "cat read-line-example.c",
  "vi hello.c",
  "make",
  "ls -al | grep xxx | grep yyy"
};*/
int history_index;//sizeof(history)/sizeof(char *);
std::vector<std::string> history;

void insert_history(std::string command) {
  history.push_back(command);
}

void read_line_print_usage()
{
  const char * usage = "\n"
    " ctrl-?       Print usage\n"
    " Backspace    Deletes last character\n"
    " up arrow     See last command in the history\n";

  write(1, usage, strlen(usage));
}

/* 
 * Input a line with some basic editing.
 */
char * read_line() {

  tty_get_old();
  // Set terminal in raw mode
  tty_raw_mode();
  line_buffer = "";
  line_length = 0;
  cursor = 0;
  history_index = history.size();
  bool up = true;
  bool first = false;
  // Read one line until enter is typed
  while (1) {

    // Read one character in raw mode.
    char ch;
    read(0, &ch, 1);
    if (ch>=32) {
      std::string prefix = line_buffer.substr(0,cursor);
      std::string suffix = line_buffer.substr(cursor, line_length - cursor);
      suffix = ch + suffix;
      write(1,suffix.c_str(),suffix.size());
      line_buffer = "";
      line_buffer = prefix + suffix;
      for (int i = 0; i < suffix.size() - 1; i++) {
        write(1, left, strlen(left));
      }
      cursor++;
      line_length++;
    }
    else if (ch==10) {
      // <Enter> was typed. Return line
      
      // Print newline
      write(1,&ch,1);
      break;
    }
    else if (ch == 31) {
      // ctrl-?
      read_line_print_usage();
      //line_buffer[0]=0;
      line_buffer = "";
      break;
    }
    else if (ch == 8 && line_length > 0 && cursor > 0) {
      // <backspace> was typed. Remove previous character read.

      std::string prefix = line_buffer.substr(0,cursor - 1);
      std::string suffix = line_buffer.substr(cursor, line_length - cursor);
      write(1,&ch,1);
      line_buffer = "";
      line_buffer = prefix + suffix;
      ch = ' ';
      for (int i = 0; i <= suffix.size(); i++) {
        write(1, &ch, 1);
      }
      ch = 8;
      for (int i = 0; i <= suffix.size(); i++) {
        write(1, &ch, 1);
      }
      write(1,suffix.c_str(),suffix.size());
      for (int i = 0; i < suffix.size(); i++) {
        write(1, left, strlen(left));
      }
      cursor--;
      line_length--;
    }
    else if (ch == 4 && line_length > 0 && cursor >= 0) {
      //Ctrl-D: Removes the character at the cursor. The characters in the right side are shifted to the left.
      if (cursor != line_length) {
        std::string prefix = line_buffer.substr(0,cursor);
        std::string suffix = line_buffer.substr(cursor + 1, line_length - cursor);
        write(1, right, strlen(right));
        ch = 8;
        write(1,&ch,1);
        line_buffer = "";
        line_buffer = prefix + suffix;
        ch = ' ';
        for (int i = 0; i <= suffix.size(); i++) {
          write(1, &ch, 1);
        }
        ch = 8;
        for (int i = 0; i <= suffix.size(); i++) {
          write(1, &ch, 1);
        }
        write(1,suffix.c_str(),suffix.size());
        for (int i = 0; i < suffix.size(); i++) {
          write(1, left, strlen(left));
        }
        line_length--;
      }
    }
    else if (ch == 1 && line_length > 0 && cursor > 0) {
      //Home key (ctrl-A): The cursor moves to the beginning of the line
      while (cursor != 0) {
        write(1, left, strlen(left));
        cursor--;
      }
    }
    else if (ch == 5 && line_length > 0 && cursor >= 0) {
      //End key (ctrl-E): The cursor moves to the end of the line
      while (cursor != line_length) {
        write(1, right, strlen(right));
        cursor++;
      }
    }
    else if (ch==27) {
      // Escape sequence. Read two chars more
      //
      // HINT: Use the program "keyboard-example" to
      // see the ascii code for the different chars typed.
      //
      char ch1; 
      char ch2;
      read(0, &ch1, 1);
      read(0, &ch2, 1);
      if (ch1==91 && ch2==65 && history.size() > 0) {
        // Up arrow. Print next line in history.
        
        // Erase old line
        // Print backspaces
        int i = 0;
        for (i =0; i < line_length; i++) {
          ch = 8;
          write(1,&ch,1);
        }

        // Print spaces on top
        for (i =0; i < line_length; i++) {
          ch = ' ';
          write(1,&ch,1);
        }

        // Print backspaces
        for (i =0; i < line_length; i++) {
          ch = 8;
          write(1,&ch,1);
        }	
        //write(1,&history_index,1);
        if (!up) {
          if (history_index == 1) {
            history_index = history.size() - 1;
          }
          else if (history_index == 2) {
            history_index = history.size();
          }
          else {
            history_index -= 2;
          }
        }
        line_buffer = "";
        line_buffer = history.at(history_index - 1);
        line_length = line_buffer.size();
        cursor = line_length;
        //history_index--;// = (history_index-1);//%history.size();
        if (history_index == 1) {
          history_index = history.size();
        }
        else {
          history_index--;
        }
        write(1,line_buffer.c_str(), line_length);
        up = true;
        if (!first){
          first = true;
        }
      }
      
      if (ch1==91 && ch2==66 && history.size() > 0 && first) {
        // Down arrow. Print prev line in history.
        
        // Erase old line
        // Print backspaces
        int i = 0;
        for (i =0; i < line_length; i++) {
          ch = 8;
          write(1,&ch,1);
        }

        // Print spaces on top
        for (i =0; i < line_length; i++) {
          ch = ' ';
          write(1,&ch,1);
        }

        // Print backspaces
        for (i =0; i < line_length; i++) {
          ch = 8;
          write(1,&ch,1);
        }
        if (up) {
          if (history_index == history.size()) {
            history_index = 2;
          }
          else if (history_index == history.size() - 1) {
            history_index = 1;
          }
          else {
            history_index += 2;
          }
        }	
        //write(1,&history_index,1);
        line_buffer = "";
        line_buffer = history.at(history_index - 1);
        line_length = line_buffer.size();
        cursor = line_length;
        //history_index--;// = (history_index-1);//%history.size();
        if (history_index == history.size()) {
          history_index = 1;
        }
        else {
          history_index++;
        }
        write(1,line_buffer.c_str(), line_length);
        up =false;
      }

      if (ch1==91 && ch2==67 && cursor < line_length) {
        //Right arrow key
        write(1, right, strlen(right));
        cursor++;  
      }

      if (ch1==91 && ch2==68 && cursor > 0) {
        //Left arrow key
        write(1, left, strlen(left));
        cursor--;  
      }
    }
  }
  // Add eol and null char at the end of string
  
  line_buffer += "\n"; 
  tty_term_mode();
  //char *line_buff = strdup(line_buffer.c_str());
  //line_buffer = "";
  return (char *) line_buffer.c_str();
}

