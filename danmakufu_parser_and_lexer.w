
===========================================================

Парсер и лексер danmakufu

Потокочистые версии парсера и лексера не позволяют(по крайней мере у меня
не получилось) перебрасываться частью инфы(например имя файла). Поэтому
я сделал одноразовые. Надо их чистить после их работы.
Парсер и лексер должны быть встроены, а не быть отдельным файлом, потому
как не все ОС позволят его запустить.

Грамматика danmakufu script



@o danmakufu_parser.h @{
@<danmakufu_parser.h prototypes@>
@}
Header может генерировать и bison, но как-то там сложно с распихиванием
  объектов, поэтому лучше так.

@o danmakufu_parser.y @{

%code top {
@<License@>
}

%{
@<danmakufu_parser.y C defines@>
%}

@<danmakufu_parser.y Bison defines@>
%%
@<danmakufu_parser.y grammar@>
%%
@<danmakufu_parser.y code@>
@}

@d danmakufu_parser.y C defines @{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "ast.h"

static int yylex (void);
extern FILE *yyin;
static char *global_filename;
@}
в filename хранится имя файла, который обрабатывается в данный момент
yyin - внутренняя переменная flex, из этого потока считываются лексемы.

@d danmakufu_parser.y code @{
static void yyerror(const char *str) {
    fprintf(stderr, "error: %s\n", str);
}
@}

@d danmakufu_parser.y C defines @{
static void yyerror(const char *str);
@}

Инициализируем таблицу символов, задаём имя первого файла,
начинаем синтаксический анализ:
@d danmakufu_parser.y code @{
/*
int main() {

    ast_init();

    danmakufu_parse("/dev/shm/Juuni Jumon - Summer Interlude/script/Juuni Jumon - Full Game.txt");

    // ast_clear();
    ast_print(toplevel_cons);

    return 0;
}
*/
@}

TODO: - сделать вместо main -- функцию которая принимает путь до скриптового файла
        Вместо init_x и clear_x выше используется ast_init, ast_clear, но(!)
        их надо вызывать ни в самой функции, которая принимает путь до файла(funcX), а в функции
        которая вызывает funcX, потом выполняет ast, а уже потом вызывает ast_clear.
      - лучше чистить мусор
      - почистить пространство имён
      - сделать оператор индекса [], оператором, а не костылём.
        Комментарий: лучше так не делать, потому что есть присваивание индексу, но
          нет присваивания функции.


Функция начала парсинга файла:
@d danmakufu_parser.y code @{
AstCons *danmakufu_parse(char *filename) {
    global_filename = filename;

    yyin = fopen(filename, "r");

    if(yyparse() == 0)
        return toplevel_cons;

    return NULL;
}
@}
её и нужно вызывать, чтобы получить ast.

@d danmakufu_parser.h prototypes @{
AstCons *danmakufu_parse(char *filename);
@}

Подключаем лексер:
@d danmakufu_parser.y code @{
#include "lex.yy.c"
@}


@d danmakufu_parser.y C defines @{
AstCons *danmakufu_parse(char *filename);
@}

Глобальная переменная, хранит cons верхнего уровня, его будет возвращать
функция danmakufu_parse:
@d danmakufu_parser.y C defines @{
static AstCons *toplevel_cons;
@}


@d danmakufu_parser.y Bison defines @{
%locations
%error-verbose

%start script
@}

Тип для всех токенов:
@d danmakufu_parser.y C defines @{
#define YYSTYPE void *
@}

@d danmakufu_parser.y C defines @{
#ifndef YYLTYPE_IS_DECLARED

typedef struct YYLTYPE {
    int first_line;
    int first_column;
    int last_line;
    int last_column;
    char *filename;
} YYLTYPE;

#define YYLTYPE_IS_DECLARED 1
#endif
@}

@d danmakufu_parser.y grammar @{
script        : /* empty */         { $$ = NULL; }
              | script toplevel     { @<danmakufu_parser.y grammar concat script@> }
              ;
@}

@d danmakufu_parser.y grammar concat script @{
if($2 != NULL) {
    if($1 == NULL)
        $$ = ast_dprogn($2, NULL);
    else
        $$ = ast_append($1, ast_add_cons($2, NULL));
} else
    $$ = $1;

toplevel_cons = $$;
@}

@d danmakufu_parser.y grammar @{
toplevel      : SCRIPT_MAIN '{' lines '}'          { @<danmakufu_parser.y grammar script main@> }
              | SCRIPT_CHILD SYMB '{' lines '}'    { @<danmakufu_parser.y grammar script child@> }
              | macros
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_ddefscriptmain(void *type, void *lines);
void *ast_ddefscriptchild(void *type, void *name, void *lines);
@}

Вернуть объект defscriptmain и defscriptchild:
@d danmakufu_parser.y code @{
void *ast_ddefscriptmain(void *type, void *lines) {
    return ast_add_cons(ast_defscriptmain,
            ast_add_cons(type,
                ast_add_cons(lines, NULL)));
}

void *ast_ddefscriptchild(void *type, void *name, void *lines) {
    return ast_add_cons(ast_defscriptchild,
            ast_add_cons(type,
                ast_add_cons(name,
                    ast_add_cons(lines, NULL))));
}
@}

@d danmakufu_parser.y grammar script main @{
$$ = ast_ddefscriptmain($1, $3);
printf("SCRIPT_MAIN\n");
@}

@d danmakufu_parser.y grammar script child @{
$$ = ast_ddefscriptchild($1, $2, $4);
@}

@d danmakufu_parser.y grammar @{
macros        : M_TOUHOUDANMAKUFU   { @<danmakufu_parser.y grammar declare script type@> }
              | M_TITLE             { @<danmakufu_parser.y grammar declare title@> }
              | M_TEXT              { @<danmakufu_parser.y grammar declare text@> }
              | M_IMAGE             { @<danmakufu_parser.y grammar declare image@> }
              | M_BACKGROUND        { @<danmakufu_parser.y grammar declare background@> }
              | M_BGM               { @<danmakufu_parser.y grammar declare bgm@> }
              | M_PLAYLEVEL         { @<danmakufu_parser.y grammar declare playlevel@> }
              | M_PLAYER            { @<danmakufu_parser.y grammar declare player@> }
              | M_SCRIPTVERSION     { @<danmakufu_parser.y grammar declare scriptversion@> }
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_ddefvar(void *name, void *expr);
@}

Вернуть объект declare:
@d danmakufu_parser.y code @{
void *ast_ddefvar(void *name, void *expr) {
    return ast_add_cons(ast_defvar,
            ast_add_cons(name,
                ast_add_cons(expr, NULL)));
}
@}

@d danmakufu_parser.y grammar declare script type @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*touhoudanmakufu*"), $1);
@}

@d danmakufu_parser.y grammar declare title @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*title*"), $1);
@}

@d danmakufu_parser.y grammar declare text @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*text*"), $1);
@}

@d danmakufu_parser.y grammar declare image @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*image*"), $1);
@}

@d danmakufu_parser.y grammar declare background @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*background*"), $1);
@}

@d danmakufu_parser.y grammar declare bgm @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*bgm*"), $1);
@}

@d danmakufu_parser.y grammar declare playlevel @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*playlevel*"), $1);
@}

@d danmakufu_parser.y grammar declare player @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*player*"), $1);
@}

@d danmakufu_parser.y grammar declare scriptversion @{
$$ = ast_ddefvar(ast_add_symbol_to_tbl("*scriptversion*"), $1);
@}

@d danmakufu_parser.y grammar @{
lines         : /* empty */           { $$ = NULL; }
              | lines line            { @<danmakufu_parser.y grammar concat lines@> }
              ;

line          : expr
              | dog_block
              | error ';'             { printf("file %s, line %d\n", @2.filename, @2.first_line); YYABORT; }
              ;
@}

@d danmakufu_parser.y grammar concat lines @{
if($2 != NULL) {
    if($1 == NULL)
        $$ = ast_dprogn($2, NULL);
    else
        $$ = ast_append($1, ast_add_cons($2, NULL));
} else
    $$ = $1;
@}

@d danmakufu_parser.y grammar @{
let           : LET SYMB '=' ret_expr ';'          { @<danmakufu_parser.y grammar let with set@> }
              | LET SYMB ';'                       { @<danmakufu_parser.y grammar let without set@> }
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_dimplet(void *name, void *exprs);
@}

Вернуть объект implet:
@d danmakufu_parser.y code @{
void *ast_dimplet(void *name, void *exprs) {
    void *t = (exprs != NULL) ? ast_add_cons(exprs, NULL) : NULL;
    return ast_add_cons(ast_implet,
            ast_add_cons(name, t));
}
@}

@d danmakufu_parser.y grammar let with set @{
$$ = ast_dimplet($2, $4);
printf("LET %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu_parser.y grammar let without set @{
$$ = ast_dimplet($2, NULL);
printf("LET %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu_parser.y grammar @{
dog_block     : DOG_NAME '{' exprs '}'   { @<danmakufu_parser.y grammar dogs@> }
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_ddog_name(void *name, void *exprs);
@}

Вернуть объект dog_name:
@d danmakufu_parser.y code @{
void *ast_ddog_name(void *name, void *exprs) {
    return ast_add_cons(ast_dog_name,
            ast_add_cons(name,
                ast_add_cons(exprs, NULL)));
}
@}

@d danmakufu_parser.y grammar dogs @{
$$ = ast_ddog_name($1, $3);
printf("%s\n", ((AstSymbol*)$1)->name);
@}

Процедура:
@d danmakufu_parser.y grammar @{
defsub_block  : SUB SYMB '{' exprs '}'   { @<danmakufu_parser.y grammar function without parenthesis@> }
              ;
@}
имеет тот же обработчик, что и функция без параметров.

@d danmakufu_parser.y grammar @{
deffunc_block : FUNCTION SYMB '(' ')' '{' exprs '}'      { @<danmakufu_parser.y grammar function without lets@> }
              | FUNCTION SYMB '(' lets ')' '{' exprs '}' { @<danmakufu_parser.y grammar function with lets@> }
              | FUNCTION SYMB '{' exprs '}'              { @<danmakufu_parser.y grammar function without parenthesis@> }
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_dfunction(void *name, void *lets, void *exprs);
@}

Вернуть объект function:
@d danmakufu_parser.y code @{
void *ast_dfunction(void *name, void *lets, void *exprs) {
    return ast_add_cons(ast_defun,
            ast_add_cons(name,
                ast_add_cons(lets,
                    ast_add_cons(exprs, NULL))));
}
@}

@d danmakufu_parser.y grammar function without lets @{
$$ = ast_dfunction($2, NULL, $6);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu_parser.y grammar function with lets @{
$$ = ast_dfunction($2, $4, $7);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu_parser.y grammar function without parenthesis @{
$$ = ast_dfunction($2, NULL, $4);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu_parser.y grammar @{
deftask_block : TASK SYMB '(' ')' '{' exprs '}'       { @<danmakufu_parser.y grammar task without lets@> }
              | TASK SYMB '(' lets ')' '{' exprs '}'  { @<danmakufu_parser.y grammar task with lets@> }
              | TASK SYMB '{' exprs '}'               { @<danmakufu_parser.y grammar task without parenthesis@> }
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_dtask(void *name, void *lets, void *exprs);
@}

Вернуть объект task:
@d danmakufu_parser.y code @{
void *ast_dtask(void *name, void *lets, void *exprs) {
    return ast_add_cons(ast_task,
                ast_add_cons(name,
                    ast_add_cons(lets,
                        ast_add_cons(exprs, NULL))));
}
@}

@d danmakufu_parser.y grammar task without lets @{
$$ = ast_dtask($2, NULL, $6);
printf("TASK %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu_parser.y grammar task with lets @{
$$ = ast_dtask($2, $4, $7);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu_parser.y grammar task without parenthesis @{
$$ = ast_dtask($2, NULL, $4);
printf("FUNCTION: %s\n", ((AstSymbol*)$2)->name);
@}

@d danmakufu_parser.y grammar @{

exprs         : /* empty */          { $$ = NULL; }
              | exprs expr           { @<danmakufu_parser.y grammar concatenate expr list@> }
              ;

expr          : ';'                  { $$ = NULL; }
              | deffunc_block
              | defsub_block
              | deftask_block
              | let
              | ret_expr ';'
              | call_keyword
              | set_op
              ;
@}
у "/* empty */" и ';' явно присваивание NULL не случайность, а необходимость. Иначе
  ';' будет вставлять какой-то мусор.

@d danmakufu_parser.y C defines @{
void *ast_dprogn(void *first, void *others);
@}

Вернуть объект progn:
@d danmakufu_parser.y code @{
void *ast_dprogn(void *first, void *others) {
    return ast_add_cons(ast_progn,
            ast_add_cons(first, others));
}
@}

@d danmakufu_parser.y grammar concatenate expr list @{
if($2 != NULL) {
    if($1 == NULL)
        $$ = ast_dprogn($2, NULL);
    else
        $$ = ast_append($1, ast_add_cons($2, NULL));
} else
    $$ = $1;
@}

Выражение после times, while, ascent и descent:
@d danmakufu_parser.y grammar @{
exprs_after_cycle : '{' exprs '}'              { $$ = $2; }
                  | LOOP '{' exprs '}'         { $$ = $3; }
                  ;
@}

@d danmakufu_parser.y grammar @{
call_keyword  : YIELD ';'                                    { $$ = ast_add_cons(ast_yield, NULL); }
              | BREAK ';'                                    { $$ = ast_add_cons(ast_break, NULL); }
              | RETURN ret_expr ';'                          { @<danmakufu_parser.y grammar return with expr@> }
              | RETURN ';'                                   { $$ = ast_add_cons(ast_return, NULL); }
              | LOOP '(' ret_expr ')' '{' exprs '}'          { @<danmakufu_parser.y grammar loop with args@> }
              | LOOP '{' exprs '}'                           { @<danmakufu_parser.y grammar loop without args@> }
              | TIMES '(' ret_expr ')' exprs_after_cycle     { @<danmakufu_parser.y grammar times@> }
              | WHILE '(' ret_expr ')' exprs_after_cycle     { @<danmakufu_parser.y grammar while@> }
              | LOCAL '{' exprs '}'                          { @<danmakufu_parser.y grammar local@> }
              | ascent                                       { printf("ASCENT\n"); }
              | descent                                      { printf("DESCENT\n"); }
              | if
              | alternative
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_dreturn(void *expr);
@}

Вернуть объект return:
@d danmakufu_parser.y code @{
void *ast_dreturn(void *expr) {
    return ast_add_cons(ast_return,
            ast_add_cons(expr, NULL));
}
@}

@d danmakufu_parser.y grammar return with expr @{
$$ = ast_dreturn($2);
@}

@d danmakufu_parser.y C defines @{
void *ast_dloop(void *times, void *exprs);
@}

Вернуть объект loop:
@d danmakufu_parser.y code @{
void *ast_dloop(void *times, void *exprs) {
    return ast_add_cons(ast_loop,
            ast_add_cons(times,
                ast_add_cons(exprs, NULL)));
}
@}

@d danmakufu_parser.y grammar loop with args @{
$$ = ast_dloop($3, $6);
printf("LOOP\n");
@}

@d danmakufu_parser.y grammar loop without args @{
$$ = ast_dloop(NULL, $3);
printf("LOOP\n");
@}

@d danmakufu_parser.y grammar times @{
$$ = ast_dloop($3, $5);
printf("TIMES\n");
@}

@d danmakufu_parser.y C defines @{
void *ast_dwhile(void *cond, void *exprs);
@}

Вернуть объект while:
@d danmakufu_parser.y code @{
void *ast_dwhile(void *cond, void *exprs) {
    return ast_add_cons(ast_while,
            ast_add_cons(cond,
                ast_add_cons(exprs, NULL)));
}
@}

@d danmakufu_parser.y grammar while @{
$$ = ast_dwhile($3, $5);
printf("WHILE\n");
@}


@d danmakufu_parser.y C defines @{
void *ast_dblock(void *exprs);
@}

Вернуть объект block:
@d danmakufu_parser.y code @{
void *ast_dblock(void *exprs) {
    return ast_add_cons(ast_block,
            ast_add_cons(exprs, NULL));
}
@}

@d danmakufu_parser.y grammar local @{
$$ = ast_dblock($3);
printf("LOCAL\n");
@}


Danmakufu script'ный switch:
@d danmakufu_parser.y grammar @{
alternative   : ALTERNATIVE '(' ret_expr ')' case others   { @<danmakufu_parser.y grammar alternative with others@> }
              | ALTERNATIVE '(' ret_expr ')' case          { @<danmakufu_parser.y grammar alternative without others@> }
              ;

case          : CASE '(' args ')' '{' exprs '}'            { @<danmakufu_parser.y grammar case1@> }
              | case CASE '(' args ')' '{' exprs '}'       { @<danmakufu_parser.y grammar case2@> }
              ;

others        : OTHERS '{' exprs '}'                       { @<danmakufu_parser.y grammar other@> }
              ;
@}
Выглядит как говно, зато без конфликта shift/reduce.

@d danmakufu_parser.y C defines @{
void *ast_dalternative(void *cond, void *case_, void *others_);
void *ast_dcase(void *args, void *exprs);
@}

Вернуть объект alternative:
@d danmakufu_parser.y code @{
void *ast_dalternative(void *cond, void *case_, void *others_) {
    return ast_add_cons(ast_alternative,
            ast_add_cons(cond,
                ast_add_cons(ast_dlist(case_),
                    ast_add_cons(others_, NULL))));
}
@}

Вернуть объект case:
@d danmakufu_parser.y code @{
void *ast_dcase(void *args, void *exprs) {
    return ast_add_cons(ast_case,
            ast_add_cons(ast_dlist(args),
                ast_add_cons(exprs, NULL)));
}
@}

@d danmakufu_parser.y grammar alternative with others @{
$$ = ast_dalternative($3, $5, $6);
printf("ALTERNATIVE\n");
@}

@d danmakufu_parser.y grammar alternative without others @{
$$ = ast_dalternative($3, $5, NULL);
printf("ALTERNATIVE\n");
@}

@d danmakufu_parser.y grammar case1 @{
$$ = ast_add_cons(ast_dcase($3, $6), NULL);
printf("CASE\n");
@}

Если не первый case:
@d danmakufu_parser.y grammar case2 @{
$$ = ast_append($1, ast_add_cons(ast_dcase($4, $7), NULL));
printf("CASE\n");
@}

@d danmakufu_parser.y grammar other @{
$$ = $3;
printf("OTHERS\n");
@}

@d danmakufu_parser.y grammar @{
ascent        : ASCENT '(' LET SYMB IN ret_expr DOUBLE_DOT ret_expr ')' exprs_after_cycle
                                            { @<danmakufu_parser.y grammar ascent with let@> }
              | ASCENT '(' SYMB IN ret_expr DOUBLE_DOT ret_expr ')' exprs_after_cycle
                                            { @<danmakufu_parser.y grammar ascent without let@> }
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_dxcent(void *xcent, void *symb, void *from, void *to, void *exprs);
@}

Вернуть объект ascent или descent:
@d danmakufu_parser.y code @{
void *ast_dxcent(void *xcent, void *symb, void *from, void *to, void *exprs) {
    return ast_add_cons(xcent,
            ast_add_cons(symb,
                ast_add_cons(from,
                    ast_add_cons(to,
                        ast_add_cons(exprs, NULL)))));
}
@}
ascent и descent -- геморой в будущем, они вводят лишние понятия, которые можно заменить
  с помощью for(do). Возможно стоит заменить код выше, и делать преобразование в обычный do
  вместо введения ast_ascent и ast_descent.

@d danmakufu_parser.y grammar ascent with let @{
$$ = ast_dxcent(ast_ascent, ast_dimplet($4, NULL), $6, $8, $10);
@}

@d danmakufu_parser.y grammar ascent without let @{
$$ = ast_dxcent(ast_ascent, $3, $5, $7, $9);
@}

@d danmakufu_parser.y grammar @{
descent       : DESCENT '(' LET SYMB IN ret_expr DOUBLE_DOT ret_expr ')' exprs_after_cycle
                                            { @<danmakufu_parser.y grammar descent with let@> }
              | DESCENT '(' SYMB IN ret_expr DOUBLE_DOT ret_expr ')' exprs_after_cycle
                                            { @<danmakufu_parser.y grammar descent without let@> }
              ;
@}

@d danmakufu_parser.y grammar descent with let @{
$$ = ast_dxcent(ast_descent, ast_dimplet($4, NULL), $6, $8, $10);
@}

@d danmakufu_parser.y grammar descent without let @{
$$ = ast_dxcent(ast_descent, $3, $5, $7, $9);
@}


@d danmakufu_parser.y grammar @{
if            : IF '(' ret_expr ')' '{' exprs '}' else_if    { @<danmakufu_parser.y grammar if@> }
              ;

else_if       : /* empty */                                  { $$ = NULL; }
              | ELSE if                                      { @<danmakufu_parser.y grammar else if@> }
              | ELSE '{' exprs '}'                           { @<danmakufu_parser.y grammar else@> }
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_dif(void *cond, void *then, void *else_);
@}

Вернуть объект if:
@d danmakufu_parser.y code @{
void *ast_dif(void *cond, void *then, void *else_) {
    return ast_add_cons(ast_if,
            ast_add_cons(cond,
                ast_add_cons(then,
                    ast_add_cons(else_, NULL))));
}
@}

@d danmakufu_parser.y grammar if @{
$$ = ast_dif($3, $6, $8);
printf("IF %d\n", @1.first_line);
@}

@d danmakufu_parser.y grammar else if @{
$$ = $2;
printf("ELSE ");
@}

@d danmakufu_parser.y grammar else @{
$$ = $3;
printf("ELSE\n");
@}

@d danmakufu_parser.y grammar @{
indexing         : array '[' ret_expr ']'                         { @<danmakufu_parser.y grammar index@> }
                 | array '[' ret_expr DOUBLE_DOT ret_expr ']'     { @<danmakufu_parser.y grammar slice@> }
                 | SYMB '[' ret_expr ']'                          { @<danmakufu_parser.y grammar index@> }
                 | SYMB '[' ret_expr DOUBLE_DOT ret_expr ']'      { @<danmakufu_parser.y grammar slice@> }
                 | STRING '[' ret_expr ']'                        { @<danmakufu_parser.y grammar index@> }
                 | STRING '[' ret_expr DOUBLE_DOT ret_expr ']'    { @<danmakufu_parser.y grammar slice@> }
                 | call_func '[' ret_expr ']'                     { @<danmakufu_parser.y grammar index@> }
                 | call_func '[' ret_expr DOUBLE_DOT ret_expr ']' { @<danmakufu_parser.y grammar slice@> }
                 | indexing '[' ret_expr ']'                      { @<danmakufu_parser.y grammar index@> }
                 | indexing '[' ret_expr DOUBLE_DOT ret_expr ']'  { @<danmakufu_parser.y grammar slice@> }
                 ;
@}

@d danmakufu_parser.y grammar index @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("index"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
printf("INDEX\n");
@}

@d danmakufu_parser.y grammar slice @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("slice"),
        ast_add_cons($1,
            ast_add_cons($3,
                ast_add_cons($5, NULL))));
printf("SLICE\n");
@}

@d danmakufu_parser.y grammar @{
call_func        : SYMB '(' ')'                       { @<danmakufu_parser.y grammar call without args@> }
                 | SYMB '(' args ')'                  { @<danmakufu_parser.y grammar call with args@> }
                 ;
@}
Одиночный символ -- тоже вызов функции

@d danmakufu_parser.y C defines @{
void *ast_dfuncall(void *name, void *args);
@}

Вернуть объект funcall:
@d danmakufu_parser.y code @{
void *ast_dfuncall(void *name, void *args) {
    return ast_add_cons(ast_funcall,
            ast_add_cons(name, args));
}
@}
может лучше убрать ast_funcall и сделать как в Scheme?

@d danmakufu_parser.y grammar call without args @{
$$ = ast_dfuncall($1, NULL);
printf("CALL %s\n", ((AstSymbol*)$1)->name);
@}

@d danmakufu_parser.y grammar call with args @{
$$ = ast_dfuncall($1, $3);
printf("CALL %s\n", ((AstSymbol*)$1)->name);
@}


Список аргументов при вызове функций и, возможно, чего-то ещё:
@d danmakufu_parser.y grammar @{
args          : ret_expr              { @<danmakufu_parser.y grammar args create list@> }
              | args ',' ret_expr     { @<danmakufu_parser.y grammar args concatenate@> }
              ;
@}

@d danmakufu_parser.y grammar args create list @{
$$ = ast_add_cons($1, NULL);
@}

@d danmakufu_parser.y grammar args concatenate @{
$$ = ast_append($1, ast_add_cons($3, NULL));
@}

Список параметров при объявлении функции и
  прочих подобных штук:
@d danmakufu_parser.y grammar @{
let_expr      : ret_expr
              | LET SYMB              { @<danmakufu_parser.y grammar let_expr with let@> }
              ;

lets          : let_expr              { @<danmakufu_parser.y grammar lets create list@> }
              | lets ',' let_expr     { @<danmakufu_parser.y grammar lets concatenate@> }
              ;
@}

@d danmakufu_parser.y grammar let_expr with let @{
$$ = ast_dimplet($2, NULL);
@}

@d danmakufu_parser.y grammar lets create list @{
$$ = ast_add_cons($1, NULL);
@}

Соединим два определения параметра в список:
@d danmakufu_parser.y grammar lets concatenate @{
$$ = ast_append($1, ast_add_cons($3, NULL));
@}

@d danmakufu_parser.y grammar @{
set_op_elt    : SYMB
              | indexing
              ;

set_op        : set_op_elt '=' ret_expr ';'        { @<danmakufu_parser.y grammar set operator@> }
              | set_op_elt ADD_SET_OP ret_expr ';' { @<danmakufu_parser.y grammar add set operator@> }
              | set_op_elt SUB_SET_OP ret_expr ';' { @<danmakufu_parser.y grammar sub set operator@> }
              | set_op_elt MUL_SET_OP ret_expr ';' { @<danmakufu_parser.y grammar mul set operator@> }
              | set_op_elt DIV_SET_OP ret_expr ';' { @<danmakufu_parser.y grammar div set operator@> }
              | set_op_elt INC_OP ';'              { @<danmakufu_parser.y grammar successor@> }
              | set_op_elt DEC_OP ';'              { @<danmakufu_parser.y grammar predcessor@> }
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_dsetq(void *lval, void *rval);
@}

Вернуть объект setq:
@d danmakufu_parser.y code @{
void *ast_dsetq(void *lval, void *rval) {
    return ast_add_cons(ast_setq,
            ast_add_cons(lval,
                ast_add_cons(rval, NULL)));
}
@}

@d danmakufu_parser.y grammar set operator @{
$$ = ast_dsetq($1, $3);
@}

@d danmakufu_parser.y grammar add set operator @{
$$ = ast_dsetq($1,
        ast_dfuncall(ast_add_symbol_to_tbl("add"),
            ast_add_cons($1,
                ast_add_cons($3, NULL))));
@}

@d danmakufu_parser.y grammar sub set operator @{
$$ = ast_dsetq($1,
        ast_dfuncall(ast_add_symbol_to_tbl("subtract"),
            ast_add_cons($1,
                ast_add_cons($3, NULL))));
@}

@d danmakufu_parser.y grammar mul set operator @{
$$ = ast_dsetq($1,
        ast_dfuncall(ast_add_symbol_to_tbl("multiply"),
            ast_add_cons($1,
                ast_add_cons($3, NULL))));
@}

@d danmakufu_parser.y grammar div set operator @{
$$ = ast_dsetq($1,
        ast_dfuncall(ast_add_symbol_to_tbl("divide"),
            ast_add_cons($1,
                ast_add_cons($3, NULL))));
@}

@d danmakufu_parser.y grammar successor @{
$$ = ast_dsetq($1,
        ast_dfuncall(ast_add_symbol_to_tbl("successor"),
            ast_add_cons($1, NULL)));
@}

@d danmakufu_parser.y grammar predcessor @{
$$ = ast_dsetq($1,
        ast_dfuncall(ast_add_symbol_to_tbl("predcessor"),
            ast_add_cons($1, NULL)));
@}


Типы, которые возвращают значание:
@d danmakufu_parser.y grammar @{
ret_expr      : NUM
              | SYMB
              | STRING
              | CHARACTER
              | call_func
              | indexing
              | array
              | ret_expr '+' ret_expr          { @<danmakufu_parser.y grammar ret_expr add@> }
              | ret_expr '-' ret_expr          { @<danmakufu_parser.y grammar ret_expr sub@> }
              | ret_expr '*' ret_expr          { @<danmakufu_parser.y grammar ret_expr mul@> }
              | ret_expr '/' ret_expr          { @<danmakufu_parser.y grammar ret_expr div@> }
              | ret_expr '%' ret_expr          { @<danmakufu_parser.y grammar ret_expr mod@> }
              | ret_expr '<' ret_expr          { @<danmakufu_parser.y grammar ret_expr less@> }
              | ret_expr LE_OP ret_expr        { @<danmakufu_parser.y grammar ret_expr less-equal@> }
              | ret_expr '>' ret_expr          { @<danmakufu_parser.y grammar ret_expr greater@> }
              | ret_expr GE_OP ret_expr        { @<danmakufu_parser.y grammar ret_expr greater-equal@> }
              | ret_expr '^' ret_expr          { @<danmakufu_parser.y grammar ret_expr pow@> }
              | ret_expr '~' ret_expr          { @<danmakufu_parser.y grammar ret_expr concatenate@> }
              | ret_expr LOGICAL_OR ret_expr   { @<danmakufu_parser.y grammar ret_expr logical or@> }
              | ret_expr LOGICAL_AND ret_expr  { @<danmakufu_parser.y grammar ret_expr logical and@> }
              | ret_expr EQUAL_OP ret_expr     { @<danmakufu_parser.y grammar ret_expr equal@> }
              | ret_expr NOT_EQUAL_OP ret_expr { @<danmakufu_parser.y grammar ret_expr not equal@> }
              | NOT ret_expr                   { @<danmakufu_parser.y grammar ret_expr not@> }
              | '-' ret_expr %prec NEG         { @<danmakufu_parser.y grammar ret_expr negative@> }
              | '|' ret_expr '|'               { @<danmakufu_parser.y grammar ret_expr abs@> }
              | '(' ret_expr ')'               { $$ = $2; }
              ;
@}

@d danmakufu_parser.y grammar ret_expr add @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("add"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr sub @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("subtract"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr mul @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("multiply"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr div @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("divide"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr mod @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("remainder"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr less @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("<"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr less-equal @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("<="),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr greater @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl(">"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr greater-equal @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl(">="),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr pow @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("power"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr concatenate @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("concatenate"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr logical or @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("or"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr logical and @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("and"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr equal @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("equalp"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
@}

@d danmakufu_parser.y grammar ret_expr not equal @{
void *o;
o = ast_dfuncall(ast_add_symbol_to_tbl("equalp"),
        ast_add_cons($1,
            ast_add_cons($3, NULL)));
$$ = ast_dfuncall(ast_add_symbol_to_tbl("not"),
        ast_add_cons(o, NULL));
@}

@d danmakufu_parser.y grammar ret_expr not @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("not"),
        ast_add_cons($2, NULL));
@}

@d danmakufu_parser.y grammar ret_expr negative @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("negative"),
        ast_add_cons($2, NULL));
@}

@d danmakufu_parser.y grammar ret_expr abs @{
$$ = ast_dfuncall(ast_add_symbol_to_tbl("absolute"),
        ast_add_cons($2, NULL));
@}

@d danmakufu_parser.y grammar @{
array         : '[' ']'                         { @<danmakufu_parser.y grammar make-array empty@> }
              | '[' array_args ']'              { @<danmakufu_parser.y grammar make-array@> }
              | '[' array_args ',' ']'          { @<danmakufu_parser.y grammar make-array@> }
              ;

array_args    : ret_expr                        { @<danmakufu_parser.y grammar create array_args@> }
              | array_args ',' ret_expr         { @<danmakufu_parser.y grammar concat array_args@> }
              ;
@}

@d danmakufu_parser.y C defines @{
void *ast_dmake_array(void *args);
@}

Вернуть объект make-array:
@d danmakufu_parser.y code @{
void *ast_dmake_array(void *args) {
    if(args == NULL)
        return ast_add_cons(ast_make_array, NULL);
    else
        return ast_add_cons(ast_make_array,
                ast_add_cons(ast_dlist(args), NULL));
}
@}

@d danmakufu_parser.y grammar make-array empty @{
$$ = ast_dmake_array(NULL);
printf("ARRAY\n");
@}

@d danmakufu_parser.y grammar make-array @{
$$ = ast_dmake_array($2);
printf("ARRAY\n");
@}

@d danmakufu_parser.y C defines @{
void *ast_dlist(void *args);
@}

Вернуть объект list:
@d danmakufu_parser.y code @{
void *ast_dlist(void *args) {
    return ast_add_cons(ast_list, args);
}
@}

@d danmakufu_parser.y grammar create array_args @{
$$ = ast_add_cons($1, NULL);
@}

@d danmakufu_parser.y grammar concat array_args @{
$$ = ast_append($1, ast_add_cons($3, NULL));
@}

@d danmakufu_parser.y Bison defines @{
%token LOGICAL_OR
%token LOGICAL_AND

%token EQUAL_OP
%token NOT_EQUAL_OP

%token ADD_SET_OP
%token SUB_SET_OP
%token MUL_SET_OP
%token DIV_SET_OP
%token INC_OP
%token DEC_OP

%left LOGICAL_OR LOGICAL_AND
%left EQUAL_OP NOT_EQUAL_OP '<' LE_OP '>' GE_OP
%left '-' '+' '~'
%left '*' '/' '%'
%left NEG NOT
%right '^'


%token NUM
%token STRING
%token CHARACTER

%token SYMB

%token DOG_NAME

%token SCRIPT_MAIN
%token SCRIPT_CHILD

%token LET
%token RETURN
%token IF
%token ELSE
%token YIELD
%token TASK
%token LOOP
%token TIMES
%token WHILE
%token LOCAL
%token ALTERNATIVE
%token CASE
%token OTHERS
%token ASCENT
%token DESCENT
%token IN
%token DOUBLE_DOT
%token BREAK
%token SUB
%token FUNCTION
@}


Макросы:
@d danmakufu_parser.y Bison defines @{
%token M_TOUHOUDANMAKUFU
%token M_TITLE
%token M_TEXT
%token M_IMAGE
%token M_BACKGROUND
%token M_BGM
%token M_PLAYLEVEL
%token M_PLAYER
%token M_SCRIPTVERSION
@}

Лексика danmakufu script

@o danmakufu_lexer.lex @{
%{
@<danmakufu_lexer.lex C defines@>
%}

@<danmakufu_lexer.lex Lex defines@>
%%
@<danmakufu_lexer.lex vocabulary@>
%%
@<danmakufu_lexer.lex code@>
@}


@d danmakufu_lexer.lex Lex defines @{
%option noyywrap
@}

@d danmakufu_lexer.lex vocabulary @{
let                 return LET;
function            return FUNCTION;
sub                 return SUB;
task                return TASK;
yield               return YIELD;
break               return BREAK;
if                  return IF;
else                return ELSE;
loop                return LOOP;
times               return TIMES;
while               return WHILE;
local               return LOCAL;
alternative         return ALTERNATIVE;
case                return CASE;
others              return OTHERS;
ascent              return ASCENT;
descent             return DESCENT;
in                  return IN;
".."                return DOUBLE_DOT;
return              return RETURN;

script_enemy_main   { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_MAIN; }
script_stage_main   { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_MAIN; }
script_player_main  { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_MAIN; }

script_enemy        { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_CHILD; }
script_shot         { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_CHILD; }
script_spell        { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_CHILD; }
script_event        { yylval=ast_add_symbol_to_tbl(yytext); return SCRIPT_CHILD; }

@Initialize         { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@MainLoop           { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@DrawLoop           { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@Finalize           { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@BackGround         { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}
@DrawTopObject      { yylval=ast_add_symbol_to_tbl(yytext); return DOG_NAME;}

\+                  return '+';
-                   return '-';
\*                  return '*';
\/                  return '/';
%                   return '%';
\^                  return '^';
\<                  return '<';
"<="                return LE_OP;
\>                  return '>';
">="                return GE_OP;
=                   return '=';
;                   return ';';
~                   return '~';
,                   return ',';

\!                  return NOT;

\(                  return '(';
\)                  return ')';
\{                  return '{';
\}                  {@<danmakufu_lexer.lex closed curly bracket@>
                    }
\[                  return '[';
\]                  return ']';

"||"                return LOGICAL_OR;
&&                  return LOGICAL_AND;

\\=                 return DIV_SET_OP;
"*="                return MUL_SET_OP;
-=                  return SUB_SET_OP;
"+="                return ADD_SET_OP;
"++"                return INC_OP;
--                  return DEC_OP;

==                  return EQUAL_OP;
!=                  return NOT_EQUAL_OP;

\|                  return '|';

false               { yylval = ast_copy_obj(ast_false); return NUM; }
true                { yylval = ast_copy_obj(ast_true); return NUM; }
pi                  { yylval = ast_copy_obj(ast_pi); return NUM; }
@}

Будем возвращаеть перед каждым '}' ещё и ';':
@d danmakufu_lexer.lex closed curly bracket @{
if(lexer_curly_bracket == 0) {
    lexer_curly_bracket = 1;
    unput('}');
    return ';';
} else {
    lexer_curly_bracket = 0;
    return '}';
}
@}
Для '\n' не делать(!), так как можно запороть объявления функций на
  несколько строк. Пока не встретишь пример, что так делают не делать!

@d danmakufu_lexer.lex C defines @{
static int lexer_curly_bracket;
@}


@d danmakufu_lexer.lex vocabulary @{
{DIGIT}+                        { @<danmakufu_lexer.lex digits@>
                                }
{DIGIT}+"."{DIGIT}+             { @<danmakufu_lexer.lex digits@>
                                }
@}

@d danmakufu_lexer.lex digits @{
yylval = ast_add_number(atof(yytext));
return NUM;
@}

@d danmakufu_lexer.lex Lex defines @{
DIGIT               [0-9]
@}

@d danmakufu_lexer.lex vocabulary @{
{STRING}            { yylval = ast_latin_string(remove_quotes(yytext, yyleng)); return STRING; }
{CHARACTER}         { yylval = ast_latin_string(remove_quotes(yytext, yyleng)); return CHARACTER; }
@}

@d danmakufu_lexer.lex Lex defines @{
STRING              \"[^\"]*\"
CHARACTER           \'[^\']*\'
@}

Разрушающая функция, которая удаляет кавычки:
@d danmakufu_lexer.lex C defines @{
static char *remove_quotes(char *str, int len);
@}

@d danmakufu_lexer.lex code @{
static char *remove_quotes(char *str, int len) {
    int i, j;

    for(i = 0; i < len-1; i++)
        if(str[i] == '\"' || str[i] == '\'') {
            i++;
            break;
        }

    for(j = len-1; j > i; j--)
        if(str[j] == '\"' || str[j] == '\'') {
            str[j] = '\0';
            break;
        }

    return &str[i];
}
@}

Добавляем найденный символ в таблицу и возвращаем токен синтаксическому анализатору:
@d danmakufu_lexer.lex vocabulary @{
[[:alpha:]_][[:alnum:]_]*    { yylval = ast_add_symbol_to_tbl(yytext); return SYMB; }
@}


Макросы:
@d danmakufu_lexer.lex vocabulary @{
#TouhouDanmakufu              { yylval = NULL; return M_TOUHOUDANMAKUFU; }
#TouhouDanmakufu{IN_BRACKETS} { @<danmakufu_lexer.lex vocabulary to-string@>
                                return M_TOUHOUDANMAKUFU; }
#\x93\x8c\x95\xfb\x92\x65\x96\x8b\x95\x97              { yylval = NULL; return M_TOUHOUDANMAKUFU; }
#\x93\x8c\x95\xfb\x92\x65\x96\x8b\x95\x97{IN_BRACKETS} { @<danmakufu_lexer.lex vocabulary to-string@>
                                                         return M_TOUHOUDANMAKUFU; }
#Title{IN_BRACKETS}          { @<danmakufu_lexer.lex vocabulary to-string@>
                               return M_TITLE; }
#Text{IN_BRACKETS}           { @<danmakufu_lexer.lex vocabulary to-string@>
                               return M_TEXT; }
#Image{IN_BRACKETS}          { @<danmakufu_lexer.lex vocabulary to-string@>
                               return M_IMAGE; }
#BackGround{IN_BRACKETS}     { @<danmakufu_lexer.lex vocabulary to-string@>
                               return M_BACKGROUND; }
#BGM{IN_BRACKETS}            { @<danmakufu_lexer.lex vocabulary to-string@>
                               return M_BGM; }
#PlayLevel{IN_BRACKETS}      { @<danmakufu_lexer.lex vocabulary to-string@>
                               return M_PLAYLEVEL; }
#Player{IN_BRACKETS}         { @<danmakufu_lexer.lex vocabulary to-string@>
                               return M_PLAYER; }
#ScriptVersion{IN_BRACKETS}  { @<danmakufu_lexer.lex vocabulary to-string@>
                               return M_SCRIPTVERSION; }
@<danmakufu_lexer.lex vocabulary include_file@>
@}

Текст в квадратных скобках:
@d danmakufu_lexer.lex Lex defines @{
IN_BRACKETS         \[[^\]]*\]
@}

Достанем текст из квадратных скобок и вернём объект "строка":
@d danmakufu_lexer.lex vocabulary to-string @{
yylval = ast_latin_string(find_and_remove_quotes_in_macros(yytext, yyleng));
@}


Разрушающая функция, используемая в макросах(#), которая ищет текст
  содержащийся в квадратных скобках, удаляет кавычки(при необходимости) и возвращает
  этот текст:
@d danmakufu_lexer.lex C defines @{
static char *find_and_remove_quotes_in_macros(char *str, int len);
@}

@d danmakufu_lexer.lex code @{
static char *find_and_remove_quotes_in_macros(char *str, int len) {
    int i, j;

    @<find_and_remove_quotes_in_macros forward brackets@>
    /* @<find_and_remove_quotes_in_macros forward quotation marks@> */
    @<find_and_remove_quotes_in_macros backward brackets@>
    /* @<find_and_remove_quotes_in_macros backward quotation marks@> */

    str[j] = '\0';
    return &str[i];
}
@}
FIXME: что делать со строками вида [Taboo "Cross-Play"]? Убирать кавычки или нет? лучше пока
  вообще не убирать нигде

Ищем открывающую скобку:
@d find_and_remove_quotes_in_macros forward brackets @{
for(i = 0; i < len-1; i++)
    if(str[i] == '[') {
        i++;
        break;
    }
@}
когда найдём, то переходим на следующий символ, так как
  скобка нас не интересует. Выхода за границу массива нет,
  потому что len-1.

Пропускаем пробелы и одну кавычку после них, если она есть:
@d find_and_remove_quotes_in_macros forward quotation marks @{
for(; i < len-1; i++)
    if(str[i] != ' ' && str[i] != '\t')
        break;
if(str[i] == '\"')
    i++;
@}
до len-1, так как там есть по крайней мере ']'

Ищем закрывающую скобку:
@d find_and_remove_quotes_in_macros backward brackets @{
for(j = len-1; j > i; j--)
    if(str[j] == ']')
        break;
@}

Пропускаем пробелы и одну кавычку перед ниими, если она есть:
@d find_and_remove_quotes_in_macros backward quotation marks @{
if(j != i) {
    for(j = j-1; j > i; j--)
        if(str[j] != ' ' && str[j] != '\t')
            break;
    if(str[j] != '\"')
        j++;
}
@}
после прошлого шага j указывает на ']' => искать будем с j-1.
Проверка j != i нужна для случая пустых скобок "[]"(надо обратить внимание на то,
  что иначе j = j-1, те побочный эффект).

Пропускаем пробелы и символы конца строки:
@d danmakufu_lexer.lex vocabulary @{
[ \t]+                     /* empty */
[\r\n]+                    { yylloc.first_line = yylineno; yylloc.filename = global_filename; }
@}
устанавливаем номер строки и имя файла.


Поддержка #include_function:
@d danmakufu_lexer.lex vocabulary include_file @{
#include_function             BEGIN(include);
<include>[ \t]*               /* empty */;
<include>{STRING}             { @<danmakufu_lexer.lex include_function start@>
                              }
<<EOF>>                       { @<danmakufu_lexer.lex include_function stop@>
                              }
@}
Закрывающие фигурные скобки расположены так забавно из-за ошибки в myweb(а как я её сейчас найду?-_-)

Этот блок выполняется, когда открывается include файл:
@d danmakufu_lexer.lex include_function start @{
int i;

yytext[yyleng-1] = '\0';

@<danmakufu_lexer.lex include_function replace backslash to slash@>

printf("#include %s\n", &yytext[1]);

@<danmakufu_lexer.lex include_function add numline to stack@>

yyin = fopen(&yytext[1], "r");

if(yyin == NULL)
    error("error with open file");

yypush_buffer_state(yy_create_buffer(yyin, YY_BUF_SIZE));

BEGIN(INITIAL);
@}
FIXME: когда файл не найден error("") иногда вызывает segfault

Этот блок выполняется, include файл заканчивается.
Закрываем файловый поток, и вызываем yypop_buffer_state, который
заменит yyin значением предыдущего файлового потока:
@d danmakufu_lexer.lex include_function stop @{
fclose(yyin);

yypop_buffer_state();

if(!YY_CURRENT_BUFFER)
    yyterminate();

@<danmakufu_lexer.lex include_function pop numline from stack@>
@}

@d danmakufu_lexer.lex Lex defines @{
%x include
@}

unix-specific костыль:
@d danmakufu_lexer.lex include_function replace backslash to slash @{
for(i = 1; i < yyleng-1; i++)
    if(yytext[i] == '\\')
        yytext[i] = '/';
@}
почему-то fopen в linux не хочет воспринимать '\'.

Определяем стек, где будем хранить
номер текущей строки и имя текущего файла, при открытии следующего файла с
помощью #include_function:
@d danmakufu_lexer.lex C defines @{
#define MAX_INCLUDE_DEPTH 20

#define INCLUDE_FILENAME_LEN 200

struct IncludeStack {
    int num_line;
    char filename[INCLUDE_FILENAME_LEN];
};

typedef struct IncludeStack IncludeStack;

static IncludeStack include_stack[MAX_INCLUDE_DEPTH];
static int pos_num_line;
@}

Функция которая помещает в стек текущее имя файла и номер текущей строки:
@d danmakufu_lexer.lex C defines @{
static void push_include(void) {
    if(include_stack[pos_num_line].filename != global_filename) {
        strncpy(include_stack[pos_num_line].filename, global_filename, INCLUDE_FILENAME_LEN);
        include_stack[pos_num_line].filename[INCLUDE_FILENAME_LEN-1] = '\0';
    }

    include_stack[pos_num_line].num_line = yylineno;

    pos_num_line++;
    if(pos_num_line == MAX_INCLUDE_DEPTH) {
        printf("MAX_INCLUDE_DEPTH\n");
        exit(1);
    }
}
@}
global_filename определён в bison

@d danmakufu_lexer.lex C defines @{
static IncludeStack *pop_include(void) {
    pos_num_line--;

    return &include_stack[pos_num_line];
}
@}

эта опция определяет переменную yylineno, которая содержит номер строки:
@d danmakufu_lexer.lex Lex defines @{
%option yylineno
@}
она работает как-то не так и обнулять приходится самому.

Сохраняем старые global_filename и yylineno, начинаем отсчёт с первой строки,
задаём имя файла полученое от лексера:
@d danmakufu_lexer.lex include_function add numline to stack @{
push_include();
yylineno = 1;
global_filename = &yytext[1];
@}

Возвращаем старые значения yylineno и global_filename:
@d danmakufu_lexer.lex include_function pop numline from stack @{
{
    printf("#close %s\n", global_filename);

    IncludeStack *is = pop_include();
    yylineno = is->num_line;
    global_filename = is->filename;
}
@}


Удаление комментариев, однострочных:
@d danmakufu_lexer.lex vocabulary @{
\/\/[^\r\n]*                  /* empty */;
@}
и многострочных:
@d danmakufu_lexer.lex vocabulary @{
"/*"                          BEGIN(comment);
<comment>{
    "*"+"/"                   BEGIN(0);
    [^*\n]+                   ;
    "*"[^/]                   ;
    \n                        ;
}
@}
без плюса в первом правиле валился на ****/, так как звёздочки съедались
  по две и на */ нехватало.

@d danmakufu_lexer.lex Lex defines @{
%x comment
@}

