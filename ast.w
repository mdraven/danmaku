
===========================================================

Таблица символов и cons'ы

@o ast.h @{
@<License@>

#ifndef __AST_H_DANMAKU__
#define __AST_H_DANMAKU__

#include "dlist.h"

@<ast.h structs@>
@<ast.h prototypes@>

#endif /* __AST_H_DANMAKU__ */
@}


@o ast.c @{
@<License@>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "ast.h"
#include "dlist.h"

@<ast.c structs@>
@<ast.c prototypes@>
@<ast.c functions@>
@}

Типы элементов:
@d ast.h structs @{
enum {
    ast_symbol,
    ast_cons,
    ast_number,
    ast_string,
    ast_character,
    ast_function,
    ast_array
};
@}

Символ danmakufu:
@d ast.h structs @{
#define SYMBOL_MAX_LEN 40
struct AstSymbol {
    struct AstSymbol *prev;
    struct AstSymbol *next;
    struct AstSymbol *pool;
    int type;
    char name[SYMBOL_MAX_LEN];
};

typedef struct AstSymbol AstSymbol;
@}
type - указывает тип, всегда равен ast_symbol.
  Он нужен чтобы отличать в cons'ах атомы и другие cons'ы.

Список символов:
@d ast.c structs @{
static AstSymbol *symbols;
@}

Пулл символов и удалённых символов:
@d ast.c structs @{
static AstSymbol *symbols_pool;

static AstSymbol *symbols_pool_free;
static AstSymbol *symbols_end_pool_free;
@}
symbols_end_pool_free - ссылка на последний элемент symbols_pool_free

SYMBOL_ALLOC - аллоцируется слотов в самом начале
SYMBOL_ADD - добавляется при нехватке
@d ast.c structs @{
#define SYMBOL_ALLOC 1000
#define SYMBOL_ADD 100
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
static void symbols_free(AstSymbol *symbol) {
    if(symbol == symbols)
        symbols = symbols->next;

    if(symbols_pool_free == NULL)
        symbols_end_pool_free = symbol;

    dlist_free((DList*)symbol, (DList**)(&symbols_pool_free));
}
@}

Соединить symbols_pool_free с symbols_pool:
@d ast.c functions @{
static void symbols_pool_free_to_pool(void) {
    if(symbols_end_pool_free == NULL)
        return;

    symbols_end_pool_free->pool = symbols_pool;
    symbols_pool = symbols_pool_free;

    symbols_pool_free = NULL;
    symbols_end_pool_free = NULL;
}
@}

symbols_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
static AstSymbol *symbols_get_free_cell(void) {
    if(symbols_pool == NULL) {
        int k = (symbols == NULL) ? SYMBOL_ALLOC : SYMBOL_ADD;
        int i;

        symbols_pool = malloc(sizeof(AstSymbol)*k);
        if(symbols_pool == NULL) {
            fprintf(stderr, "\nCan't allocate memory for symbols' pool\n");
            exit(1);
        }

        for(i = 0; i < k-1; i++)
            symbols_pool[i].pool = &(symbols_pool[i+1]);
        symbols_pool[k-1].pool = NULL;
    }

    symbols = (AstSymbol*)dlist_alloc((DList*)symbols, (DList**)(&symbols_pool));

    return symbols;
}
@}

Функция поиска символа в таблице:
@d ast.c functions @{
static AstSymbol *find_symbol(const char *name) {
    AstSymbol *symbol;

    for(symbol = symbols; symbol != NULL; symbol = symbol->next)
        if(strcmp(symbol->name, name) == 0)
            return symbol;

    return NULL;
}
@}
NULL - если не найден.

Добавить элемент в таблицу:
@d ast.c functions @{
AstSymbol *ast_add_symbol_to_tbl(const char *name) {
    AstSymbol *symbol;

    symbol = find_symbol(name);
    if(symbol != NULL)
        return symbol;

    symbol = symbols_get_free_cell();

    symbol->type = ast_symbol;

    strncpy(symbol->name, name, SYMBOL_MAX_LEN);
    symbol->name[SYMBOL_MAX_LEN-1] = '\0';

    return symbol;
}
@}


@d ast.h prototypes @{
AstSymbol *ast_add_symbol_to_tbl(const char *name);
@}

Функция очистки:
@d ast.c functions @{
static void clear_symbols(void) {
    // BLA-BLA
}
@}
вызывать при выходе из игры. Хотя можно и после завершения скрипта,
  но зачем фрагментировать память?

Cons-пара danmakufu:
@d ast.h structs @{
DLIST_DEFSTRUCT(AstCons)
    int type;
    void *car;
    void *cdr;
DLIST_ENDS(AstCons)
@}
type - указывает тип, всегда равен ast_cons.

Список занятых cons'ов, пулл свободных cons'ов и удалённых cons'ов:
@d ast.c structs @{
DLIST_SPECIAL_VARS(conses, AstCons)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d ast.c structs @{
DLIST_ALLOC_VARS(conses, 10000, 1000)
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
DLIST_FREE_FUNC(conses, AstCons)
DLIST_END_FREE_FUNC(conses, AstCons)
@}

Соединить conses_pool_free с conses_pool:
@d ast.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(conses, AstCons)
@}

conses_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
DLIST_GET_FREE_CELL_FUNC(conses, AstCons)
@}

Добавить cons в массив:
@d ast.c functions @{
AstCons *ast_add_cons(void *car, void *cdr) {
    AstCons *c = conses_get_free_cell();

    c->type = ast_cons;
    c->car = car;
    c->cdr = cdr;

    return c;
}
@}

@d ast.h prototypes @{
AstCons *ast_add_cons(void *car, void *cdr);
@}

Функция очистки массива cons'ов:
@d ast.c functions @{
static void clear_conses(void) {
    // XXXYYYZZZ
}
@}
вызвать при выходе из игры(см. clear_symbols_tbl)


Тип число:
@d ast.h structs @{
struct AstNumber {
    struct AstNumber *prev;
    struct AstNumber *next;
    struct AstNumber *pool;
    int type;
    double number;
};

typedef struct AstNumber AstNumber;
@}
type == ast_number

Список чисел:
@d ast.c structs @{
static AstNumber *numbers;
@}

Пулл чисел и удалённых чисел:
@d ast.c structs @{
static AstNumber *numbers_pool;

static AstNumber *numbers_pool_free;
static AstNumber *numbers_end_pool_free;
@}
numbers_end_pool_free - ссылка на последний элемент numbers_pool_free

NUMBER_ALLOC - аллоцируется слотов в самом начале
NUMBER_ADD - добавляется при нехватке
@d ast.c structs @{
#define NUMBER_ALLOC 1000
#define NUMBER_ADD 300
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
static void numbers_free(AstNumber *number) {
    if(number == numbers)
        numbers = numbers->next;

    if(numbers_pool_free == NULL)
        numbers_end_pool_free = number;

    dlist_free((DList*)number, (DList**)(&numbers_pool_free));
}
@}

Соединить numbers_pool_free с numbers_pool:
@d ast.c functions @{
static void numbers_pool_free_to_pool(void) {
    if(numbers_end_pool_free == NULL)
        return;

    numbers_end_pool_free->pool = numbers_pool;
    numbers_pool = numbers_pool_free;

    numbers_pool_free = NULL;
    numbers_end_pool_free = NULL;
}
@}

numbers_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
static AstNumber *numbers_get_free_cell(void) {
    if(numbers_pool == NULL) {
        int k = (numbers == NULL) ? NUMBER_ALLOC : NUMBER_ADD;
        int i;

        numbers_pool = malloc(sizeof(AstNumber)*k);
        if(numbers_pool == NULL) {
            fprintf(stderr, "\nCan't allocate memory for numbers' pool\n");
            exit(1);
        }

        for(i = 0; i < k-1; i++)
            numbers_pool[i].pool = &(numbers_pool[i+1]);
        numbers_pool[k-1].pool = NULL;
    }

    numbers = (AstNumber*)dlist_alloc((DList*)numbers, (DList**)(&numbers_pool));

    return numbers;
}
@}


Функция поиска числа в таблице:
@d ast.c functions @{
static AstNumber *find_number(double num) {
    AstNumber *number;

    for(number = numbers; number != NULL; number = number->next)
        if(number->number == num)
            return number;

    return NULL;
}
@}
NULL - если не найден.

Добавить number в массив:
@d ast.c functions @{
AstNumber *ast_add_number(double num) {
    AstNumber *number;

    number = find_number(num);
    if(number != NULL)
        return number;

    number = numbers_get_free_cell();

    number->type = ast_number;
    number->number = num;

    return number;
}
@}

@d ast.h prototypes @{
AstNumber *ast_add_number(double num);
@}

Функция очистки:
@d ast.c functions @{
static void clear_numbers(void) {
    // YAHOOO
}
@}

Строка:
@d ast.h structs @{
struct AstString {
    struct AstString *prev;
    struct AstString *next;
    struct AstString *pool;
    int type;
    char *str;
    unsigned int len;
};

typedef struct AstString AstString;
@}
type == ast_string или ast_character
len - число байтов

Список строк:
@d ast.c structs @{
static AstString *strings;
@}

Пулл строк и удалённых строк:
@d ast.c structs @{
static AstString *strings_pool;

static AstString *strings_pool_free;
static AstString *strings_end_pool_free;
@}
strings_end_pool_free - ссылка на последний элемент strings_pool_free

STRING_ALLOC - аллоцируется слотов в самом начале
STRING_ADD - добавляется при нехватке
@d ast.c structs @{
#define STRING_ALLOC 300
#define STRING_ADD 50
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
DLIST_FREE_FUNC(strings, AstString)
    free(elm->str);
    elm->str = NULL;
DLIST_END_FREE_FUNC(strings, AstString)
@}

Соединить strings_pool_free с strings_pool:
@d ast.c functions @{
static void strings_pool_free_to_pool(void) {
    if(strings_end_pool_free == NULL)
        return;

    strings_end_pool_free->pool = strings_pool;
    strings_pool = strings_pool_free;

    strings_pool_free = NULL;
    strings_end_pool_free = NULL;
}
@}

strings_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
static AstString *strings_get_free_cell(void) {
    if(strings_pool == NULL) {
        int k = (strings == NULL) ? STRING_ALLOC : STRING_ADD;
        int i;

        strings_pool = malloc(sizeof(AstString)*k);
        if(strings_pool == NULL) {
            fprintf(stderr, "\nCan't allocate memory for strings' pool\n");
            exit(1);
        }

        for(i = 0; i < k-1; i++)
            strings_pool[i].pool = &(strings_pool[i+1]);
        strings_pool[k-1].pool = NULL;
    }

    strings = (AstString*)dlist_alloc((DList*)strings, (DList**)(&strings_pool));

    return strings;
}
@}


Добавить строку в таблицу:
@d ast.c functions @{
AstString *ast_add_string(const char *str) {
    AstString *string = strings_get_free_cell();

    string->type = ast_string;

    string->len = strlen(str);

    string->str = malloc((string->len + 1)*sizeof(char));
    if(string->str == NULL) {
        fprintf(stderr, "\nCan't allocate memory for symbols' pool\n");
        exit(1);
    }

    strcpy(string->str, str);

    return string;
}
@}

@d ast.h prototypes @{
AstString *ast_add_string(const char *str);
@}

Добавить символ в таблицу:
@d ast.c functions @{
AstString *ast_add_character(const char *str) {
    AstString *string = ast_add_string(str);
    string->type = ast_character;

    return string;
}
@}

@d ast.h prototypes @{
AstString *ast_add_character(const char *str);
@}

Функция очистки:
@d ast.c functions @{
static void clear_strings(void) {
    // BLA-BLA
}
@}


Объект-функция danmakufu:
@d ast.h structs @{
DLIST_DEFSTRUCT(AstFunction)
    int type;
    int p;
DLIST_ENDS(AstFunction)
@}
type - указывает тип, всегда равен ast_function.

Список занятых function'ов, пулл свободных function'ов и удалённых function'ов:
@d ast.c structs @{
DLIST_SPECIAL_VARS(functions, AstFunction)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d ast.c structs @{
DLIST_ALLOC_VARS(functions, 100, 10)
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
DLIST_FREE_FUNC(functions, AstFunction)
DLIST_END_FREE_FUNC(functions, AstFunction)
@}

Соединить functions_pool_free с functions_pool:
@d ast.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(functions, AstFunction)
@}

functions_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
DLIST_GET_FREE_CELL_FUNC(functions, AstFunction)
@}

Добавить functions в массив:
@d ast.c functions @{
AstFunction *ast_add_functions(int p) {
    AstFunction *f = functions_get_free_cell();

    f->type = ast_function;
    f->p = p;

    return f;
}
@}

@d ast.h prototypes @{
AstFunction *ast_add_functions(int p);
@}

Функция очистки массива function'ов:
@d ast.c functions @{
static void clear_functions(void) {
    // XXXYYYZZZ
}
@}
вызвать при выходе из игры


Объект-функция danmakufu:
@d ast.h structs @{
DLIST_DEFSTRUCT(AstArray)
    int type;
    void **arr;
    int len;
DLIST_ENDS(AstArray)
@}
type - указывает тип, всегда равен ast_array
arr - массив AstXXX
len - число элементов


Список занятых array'ов, пулл свободных array'ов и удалённых array'ов:
@d ast.c structs @{
DLIST_SPECIAL_VARS(arrays, AstArray)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d ast.c structs @{
DLIST_ALLOC_VARS(arrays, 10, 10)
@}

Функция для возвращения выделенных слотов обратно в пул:
@d ast.c functions @{
DLIST_FREE_FUNC(arrays, AstArray)
DLIST_END_FREE_FUNC(arrays, AstArray)
@}

Соединить arrays_pool_free с arrays_pool:
@d ast.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(arrays, AstArray)
@}

arrays_get_free_cell - функция возвращающая свободный дескриптор:
@d ast.c functions @{
DLIST_GET_FREE_CELL_FUNC(arrays, AstArray)
@}

Добавить arrays в массив:
@d ast.c functions @{
AstArray *ast_add_arrays(int len) {
    AstArray *f = arrays_get_free_cell();

    f->type = ast_array;
    f->len = len;
    f->arr = (void**)calloc(len, sizeof(void*));
    if(f->arr == NULL) {
        fprintf(stderr, "\ncalloc returned NULL\n");
        exit(1);
    }

    return f;
}
@}
под arr память выделяется, но заполнять нужно самому после вызова ast_add_arrays

@d ast.h prototypes @{
AstArray *ast_add_arrays(int len);
@}

Функция очистки массива array'ов:
@d ast.c functions @{
static void clear_arrays(void) {
    // XXXYYYZZZ
}
@}
вызвать при выходе из игры


Инициализация ast:
@d ast.c functions @{
void ast_init(void) {
    ast_defun = ast_add_symbol_to_tbl("defun");
    ast_implet = ast_add_symbol_to_tbl("implet");
    ast_task = ast_add_symbol_to_tbl("task");
    ast_if = ast_add_symbol_to_tbl("if");
    ast_alternative = ast_add_symbol_to_tbl("alternative");
    ast_case = ast_add_symbol_to_tbl("case");
    ast_funcall = ast_add_symbol_to_tbl("funcall");
    ast_dog_name = ast_add_symbol_to_tbl("dog_name");
    ast_setq = ast_add_symbol_to_tbl("setq");
    ast_ascent = ast_add_symbol_to_tbl("ascent");
    ast_descent = ast_add_symbol_to_tbl("descent");
    ast_yield = ast_add_symbol_to_tbl("yield");
    ast_break = ast_add_symbol_to_tbl("break");
    ast_return = ast_add_symbol_to_tbl("return");
    ast_loop = ast_add_symbol_to_tbl("loop");
    ast_while = ast_add_symbol_to_tbl("while");
    ast_block = ast_add_symbol_to_tbl("block");
    ast_make_array = ast_add_symbol_to_tbl("make-array");
    ast_defscriptmain = ast_add_symbol_to_tbl("defscriptmain");
    ast_defscriptchild = ast_add_symbol_to_tbl("defscriptchild");
    ast_defvar = ast_add_symbol_to_tbl("defvar");
    ast_progn = ast_add_symbol_to_tbl("progn");
    ast_list = ast_add_symbol_to_tbl("list");

    ast_false = ast_add_number(0.0);
    ast_true = ast_add_number(1.0);
    ast_pi = ast_add_number(3.1415);
}
@}
FIXME: усложнённый язык! После того как вычислятор будет написан, стоит упростить
  язык виртуальной машины. Например вместо ascent, descent, loop, while сделать do.

Очистка ast:
@d ast.c functions @{
void ast_clear(void) {
    clear_symbols();
    clear_conses();
    clear_numbers();
    clear_strings();
    clear_functions();
    clear_arrays();
}
@}
вызвать при выходе из игры(см. clear_symbols_tbl и clear_cons_array)

@d ast.h prototypes @{
void ast_init(void);
void ast_clear(void);
@}

На часть символов будем хранить указатели. Это ускорит сравнение:
@d ast.c structs @{
AstSymbol *ast_defun;
AstSymbol *ast_implet;
AstSymbol *ast_task;
AstSymbol *ast_if;
AstSymbol *ast_alternative;
AstSymbol *ast_case;
AstSymbol *ast_funcall;
AstSymbol *ast_dog_name;
AstSymbol *ast_setq;
AstSymbol *ast_ascent;
AstSymbol *ast_descent;
AstSymbol *ast_yield;
AstSymbol *ast_break;
AstSymbol *ast_return;
AstSymbol *ast_loop;
AstSymbol *ast_while;
AstSymbol *ast_block;
AstSymbol *ast_make_array;
AstSymbol *ast_defscriptmain;
AstSymbol *ast_defscriptchild;
AstSymbol *ast_defvar;
AstSymbol *ast_progn;
AstSymbol *ast_list;

AstNumber *ast_false;
AstNumber *ast_true;
AstNumber *ast_pi;
@}

@d ast.h structs @{
extern AstSymbol *ast_defun;
extern AstSymbol *ast_implet;
extern AstSymbol *ast_task;
extern AstSymbol *ast_if;
extern AstSymbol *ast_alternative;
extern AstSymbol *ast_case;
extern AstSymbol *ast_funcall;
extern AstSymbol *ast_dog_name;
extern AstSymbol *ast_setq;
extern AstSymbol *ast_ascent;
extern AstSymbol *ast_descent;
extern AstSymbol *ast_yield;
extern AstSymbol *ast_break;
extern AstSymbol *ast_return;
extern AstSymbol *ast_loop;
extern AstSymbol *ast_while;
extern AstSymbol *ast_block;
extern AstSymbol *ast_make_array;
extern AstSymbol *ast_defscriptmain;
extern AstSymbol *ast_defscriptchild;
extern AstSymbol *ast_defvar;
extern AstSymbol *ast_progn;
extern AstSymbol *ast_list;

extern AstNumber *ast_false;
extern AstNumber *ast_true;
extern AstNumber *ast_pi;
@}
implet - императивная версия let(не как в лиспе)

Добавим поддержку операций car и cdr для удобства доступа:
@d ast.h prototypes @{
AstCons *car(AstCons *cons);
AstCons *cdr(AstCons *cons);
AstCons *caar(AstCons *cons);
AstCons *cadr(AstCons *cons);
AstCons *cdar(AstCons *cons);
AstCons *cddr(AstCons *cons);
@}

@d ast.c functions @{
AstCons *car(AstCons *cons) {
    return cons->car;
}

AstCons *cdr(AstCons *cons) {
    return cons->cdr;
}

AstCons *caar(AstCons *cons) {
    return ((AstCons*)cons->car)->car;
}

AstCons *cadr(AstCons *cons) {
    return ((AstCons*)cons->cdr)->car;
}

AstCons *cdar(AstCons *cons) {
    return ((AstCons*)cons->car)->cdr;
}

AstCons *cddr(AstCons *cons) {
    return ((AstCons*)cons->cdr)->cdr;
}
@}
функции примитивны: казалось бы, зачем они? Но они позволяют уменьшить
  количество приведений типа(значит и размер кода), что есть хорошо.

Функция append:
@d ast.h prototypes @{
AstCons *ast_append(AstCons *cons, AstCons *to_back);
@}

@d ast.c functions @{
AstCons *ast_append(AstCons *cons, AstCons *to_back) {
    if(cons == NULL) {
        fprintf(stderr, "\nast_append: Cons == NULL\n");
        exit(1);
    }

    AstCons *c;
    for(c = cons; c->type == ast_cons && c->cdr != NULL; c = c->cdr);

    if(c->type != ast_cons) {
        fprintf(stderr, "\nast_append: It isn't cons\n");
        exit(1);
    }

    c->cdr = to_back;
    return cons;
}
@}
с той же целью, что и cdr() и car().

Функция печати, нужна для отладки:
@d ast.h prototypes @{
void ast_print(const AstCons *cons);
@}

@d ast.c prototypes @{
static void ast_print_helper(const void *obj, int shift, int skip_first_shift);
@}
shift - число пробелов в отступе

@d ast.c functions @{
void ast_print(const AstCons *cons) {
    ast_print_helper(cons, 0, 0);
}

static void ast_print_helper(const void *obj, int shift, int skip_first_shift) {
    int i;

    if(skip_first_shift == 0)
        for(i = 0; i < shift; i++)
            printf(" ");

    if(obj == NULL) {
        printf("NIL");
        return;
    }

    switch(((const AstCons*)obj)->type) {
        case ast_cons: {
            const AstCons *p;

            printf("(");
            for(p = obj;
                p->cdr != NULL && ((const AstCons*)p->cdr)->type == ast_cons;
                p = p->cdr) {
                ast_print_helper(p->car, shift+1, (p == obj) ? 1 : 0);
                printf("\n");
            }
            ast_print_helper(p->car, shift+1, (p == obj) ? 1 : 0);
            if(p->cdr != NULL) {
                printf(" .\n");
                ast_print_helper(p->cdr, shift+1, 0);
            }
            printf(")");

            /*
            const AstCons *cons = obj;
            printf("(cons\n");
            ast_print_helper(cons->car, shift+1, 0);
            printf("\n");
            ast_print_helper(cons->cdr, shift+1, 0);
            printf(")");
            */
            break;
        }
        case ast_symbol: {
            const AstSymbol *symb = obj;
            printf("%s", symb->name);
            break;
        }
        case ast_string: {
            const AstString *str = obj;
            printf("\"%s\"", str->str);
            break;
        }
        case ast_character: {
            const AstString *chr = obj;
            printf("'%s'", chr->str);
            break;
        }
        case ast_number: {
            const AstNumber *num = obj;
            printf("%f", num->number);
            break;
        }
        default:
            fprintf(stderr, "\nast_print_helper: unknown object\n");
            exit(1);
            break;
    }
}
@}