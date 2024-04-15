#ifndef shell_hh
#define shell_hh

#include "command.hh"

struct Shell {

  static std::string path;

  static void prompt();

  static Command _currentCommand;
};

#endif
