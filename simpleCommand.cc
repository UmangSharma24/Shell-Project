#include <cstdio>
#include <cstdlib>

#include <regex>
#include <iostream>
#include <sys/types.h>
#include <unistd.h>
#include <limits.h>
#include <stdlib.h>

#include "simpleCommand.hh"

SimpleCommand::SimpleCommand() {
  _arguments = std::vector<std::string *>();
}

SimpleCommand::~SimpleCommand() {
  // iterate over all the arguments and delete them
  for (auto & arg : _arguments) {
    delete arg;
  }
}



void SimpleCommand::insertArgument( std::string * argument ) {
  
  //printf("In insertArgument\n");

  std::regex temp1 {"^.*\\$\\{[^\\}][^\\}]*\\}.*$"};
  std::string argString = *argument;

  //printf("%s", argString.c_str());

  if (std::regex_match (argString, temp1)) {

    //printf("found match\n");

    std::smatch match;
    std::regex temp2 {"\\$\\{[^\\}][^\\}]*\\}"};
    *argument = "";

    while (std::regex_search(argString, match, temp2)) {

      *argument += match.prefix().str();

       //Extracting the contents of the ${ }
       std::string varName = match.str().substr(2, match.str().size() - 3);
       
      if (varName.compare("?") == 0) {
        *argument += getenv("status?");
      }
      else if (varName.compare("_") == 0) {
        *argument += getenv("underscore");
      }
      else if (varName.compare("!") == 0) {
        *argument += getenv("bangPID");
      }
      else if (varName.compare("$") == 0) {
        *argument += std::to_string(getpid());
      }
      else if (varName.compare("SHELL") == 0) {
        char* absolute_path = realpath(real_path.c_str(), NULL);
        *argument += absolute_path;
        //Free allotted memory
        free(absolute_path);
      }
      else {
        *argument += getenv(varName.c_str());
      }

      argString = match.suffix().str();
      std::smatch temp_match;
      std::regex_search(argString, temp_match, temp2);

      if (temp_match.size() == 0) {
        *argument += argString;
      }
    }
  }
  _arguments.push_back(argument);
}

// Print out the simple command
void SimpleCommand::print() {
  for (auto & arg : _arguments) {
    std::cout << "\"" << *arg << "\" \t";
  }
  // effectively the same as printf("\n\n");
  std::cout << std::endl;
}
