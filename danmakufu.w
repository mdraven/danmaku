

===========================================================

Danmakufu вычислятор

Проблема в том что разных скриптов, в котором есть @BlaBla элементы,
  очень много: этажа, монстров итд
А ещё есть разные версии самого скрипта.

TODO: надо узнать, общее пространство имён(например объявленые функции) у разных скриптов
  или одно.


@o danmakufu.h @{
@<License@>
#include <stdint.h>

#include "dlist.h"
#include "ast.h"
#include "characters.h"

@<danmakufu.h structs@>
@<danmakufu.h prototypes@>
@}

@o danmakufu.c @{
@<License@>

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include "danmakufu.h"
#include "danmakufu_bytecode.h"
#include "danmakufu_parser.h"

@<danmakufu.c structs@>
@<danmakufu.c prototypes@>
@<danmakufu.c stack functions@>
@<danmakufu.c rstack functions@>
@<danmakufu.c functions@>
@}


Типы кода:
@d danmakufu.h structs @{
enum {
    danmakufu_bytecode,
    danmakufu_i386,
};
@}

Словарь:
@d danmakufu.h structs @{
DLIST_DEFSTRUCT(DanmakufuDict)
    AstSymbol *symb;
    void *ptr;
DLIST_ENDS(DanmakufuDict)
@}
symb, ptr - символ и его значение.

Список занятых, свободных и удалённых элементов:
@d danmakufu.c structs @{
DLIST_SPECIAL_VARS(danmakufu_dicts, DanmakufuDict)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d danmakufu.c structs @{
DLIST_ALLOC_VARS(danmakufu_dicts, 0xdead, 100)
@}
по-идее должно совпадать с теми же параметрами для AstSymbol


Функция для возвращения выделенных слотов обратно в пул:
@d danmakufu.c functions @{
DLIST_LOCAL_FREE_FUNC(danmakufu_dicts, DanmakufuDict)
    ast_free_recursive(elm->ptr);
DLIST_LOCAL_END_FREE_FUNC(danmakufu_dicts, DanmakufuDict)
@}


Соединить danmakufu_dicts_pool_free с danmakufu_dicts_pool:
@d danmakufu.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(danmakufu_dicts, DanmakufuDict)
@}

danmakufu_dicts_get_free_cell - функция возвращающая свободный дескриптор:
@d danmakufu.c functions @{
DLIST_LOCAL_GET_FREE_CELL_FUNC(danmakufu_dicts, DanmakufuDict)
@}

@d danmakufu.c functions @{
static DanmakufuDict *danmakufu_dict_create(DanmakufuDict *dict,
                                            AstSymbol *symb) {
    dict = danmakufu_dicts_get_free_cell(dict);

    dict->symb = symb;
    dict->ptr = NULL;

    return dict;
}
@}


@d danmakufu.c functions @{
static DanmakufuDict *danmakufu_dict_find_symbol(DanmakufuDict *dict,
                                                 const AstSymbol *symb) {
    DanmakufuDict *d;

    for(d = dict; d != NULL; d = d->next)
        if(d->symb == symb)
            return d;

    return NULL;
}
@}

@d danmakufu.c functions @{
static DanmakufuDict *copy_dict(DanmakufuDict *from) {
    DanmakufuDict *d;
    DanmakufuDict *new = NULL;

    for(d = from; d != NULL; d = d->next) {
        new = danmakufu_dict_create(new, d->symb);
        new->ptr = ast_copy_obj(d->ptr);
    }

    return new;
}
@}
символ копировать не надо так как он уже заинтернен

@d danmakufu.c functions @{
static void danmakufu_dict_clear(DanmakufuDict *dict) {
    if(dict == NULL)
        return;

    DanmakufuDict *p;
    for(p = dict->next; p != NULL; p = dict->next)
        danmakufu_dicts_free(p);
    for(p = dict->prev; p != NULL; p = dict->prev)
        danmakufu_dicts_free(p);
    danmakufu_dicts_free(dict);

    danmakufu_dicts_pool_free_to_pool();
}
@}


@d danmakufu.c functions @{
static DanmakufuDict *intern_to_dict(DanmakufuDict **head, AstSymbol *symb) {
    DanmakufuDict *dict;

    dict = danmakufu_dict_find_symbol(*head, symb);
    if(dict == NULL) {
         dict = danmakufu_dict_create(*head, symb);
         *head = dict;
    }

    return dict;
}
@}

Список словарей:
@d danmakufu.h structs @{
DLIST_DEFSTRUCT(DanmakufuDictList)
    DanmakufuDict *dict;
DLIST_ENDS(DanmakufuDictList)
@}


Список занятых, свободных и удалённых элементов:
@d danmakufu.c structs @{
DLIST_SPECIAL_VARS(danmakufu_dict_lists, DanmakufuDictList)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d danmakufu.c structs @{
DLIST_ALLOC_VARS(danmakufu_dict_lists, 0xdead, 20)
@}

Функция для возвращения выделенных словарей обратно в пул:
@d danmakufu.c functions @{
DLIST_LOCAL_FREE_FUNC(danmakufu_dict_lists, DanmakufuDictList)
    if(elm == NULL)
        return;

    if(elm->dict) {
        danmakufu_dict_clear(elm->dict);
        elm->dict = NULL;
    }
DLIST_LOCAL_END_FREE_FUNC(danmakufu_dict_lists, DanmakufuDictList)
@}

Соединить danmakufu_dict_lists_pool_free с danmakufu_dict_lists_pool:
@d danmakufu.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(danmakufu_dict_lists, DanmakufuDictList)
@}

danmakufu_dict_lists_get_free_cell - функция возвращающая свободный дескриптор:
@d danmakufu.c functions @{
DLIST_LOCAL_GET_FREE_CELL_FUNC(danmakufu_dict_lists, DanmakufuDictList)
@}

@d danmakufu.c functions @{
static DanmakufuDictList *danmakufu_dict_list_create(DanmakufuDictList *dict_list) {
    dict_list = danmakufu_dict_lists_get_free_cell(dict_list);

    dict_list->dict = NULL;

    return dict_list;
}
@}


@d danmakufu.c functions @{
static DanmakufuDict *danmakufu_dict_list_find_symbol(DanmakufuDictList *dict_list,
                                                      const AstSymbol *symb) {
    DanmakufuDictList *d;

    for(d = dict_list; d != NULL; d = d->next) {
        DanmakufuDict *t = danmakufu_dict_find_symbol(d->dict, symb);
        if(t)
            return t;
    }

    return NULL;
}
@}


Удалить все элементы из списка:
@d danmakufu.c functions @{
static void danmakufu_dict_list_clear(DanmakufuDictList *dict_list) {
    if(dict_list == NULL)
        return;

    DanmakufuDictList *p;
    for(p = dict_list->next; p != NULL; p = dict_list->next)
        danmakufu_dict_lists_free(p);
    for(p = dict_list->prev; p != NULL; p = dict_list->prev)
        danmakufu_dict_lists_free(p);
    danmakufu_dict_lists_free(dict_list);

    danmakufu_dict_lists_pool_free_to_pool();
}
@}

@d danmakufu.c functions @{
static DanmakufuDictList *copy_dict_list(DanmakufuDictList *from) {
    DanmakufuDictList *d;
    DanmakufuDictList *new = NULL;

    for(d = from; d != NULL; d = d->next) {
        new = danmakufu_dict_list_create(new);
        new->dict = copy_dict(d->dict);
    }

    return new;
}
@}


Задача:
@d danmakufu.h structs @{
#define DANMAKUFU_TASK_STACK_SIZE 50
#define DANMAKUFU_TASK_RSTACK_SIZE 50

DLIST_DEFSTRUCT(DanmakufuTask)
    int ip;
    DanmakufuDictList *local;

    void *stack[DANMAKUFU_TASK_STACK_SIZE];
    int sp;

    int rstack[DANMAKUFU_TASK_RSTACK_SIZE];
    int rp;
DLIST_ENDS(DanmakufuTask)
@}
next - указатель на следующую задачу
ip - место выполнения процесса
local - указатель на список локальных словарей задачи(определения могут перекрываться);
  используется в качестве скопа
stack - указывает на элементы из ast(например: ast_array или ast_number).
  Его можно сделать циклическим. Это позволит не заботится о функциях, которые что-то возвращают,
  и не дропать стек. Другой вариант(более эффективный): во время генерации байткода заполнять стек
  и использовать команду bc_stack. Те эмулировать регистры.
sp - позиция в стеке
rstack - стек адресов возврата
rp - позиция в стеке

Список занятых, свободных и удалённых элементов:
@d danmakufu.c structs @{
DLIST_SPECIAL_VARS(danmakufu_tasks, DanmakufuTask)
@}

Аллоцируется слотов в самом начале и добавляется при нехватке:
@d danmakufu.c structs @{
DLIST_ALLOC_VARS(danmakufu_tasks, 0xdead, 10)
@}
по-идее должно совпадать с теми же параметрами для AstSymbol


Функция для возвращения выделенных слотов обратно в пул:
@d danmakufu.c functions @{
DLIST_LOCAL_FREE_FUNC(danmakufu_tasks, DanmakufuTask)
    if(elm == NULL)
        return;

    danmakufu_dict_list_clear(elm->local);

    while(!stack_empty(elm))
        ast_free_recursive(danmakufu_stack_pop(elm));

DLIST_LOCAL_END_FREE_FUNC(danmakufu_tasks, DanmakufuTask)
@}


Соединить danmakufu_tasks_pool_free с danmakufu_tasks_pool:
@d danmakufu.c functions @{
DLIST_POOL_FREE_TO_POOL_FUNC(danmakufu_tasks, DanmakufuTask)
@}

danmakufu_tasks_get_free_cell - функция возвращающая свободный дескриптор:
@d danmakufu.c functions @{
DLIST_LOCAL_GET_FREE_CELL_FUNC(danmakufu_tasks, DanmakufuTask)
@}


@d danmakufu.c functions @{
static DanmakufuTask *danmakufu_create_new_task(DanmakufuTask *next_task) {
    DanmakufuTask *task = danmakufu_tasks_get_free_cell(next_task);
    if(task == NULL) {
        fprintf(stderr, "\nCan't allocate memory for danmakufu_task\n");
        exit(1);
    }

    task->ip = 0;
    task->local = danmakufu_dict_list_create(NULL);
    task->sp = 0;
    task->rp = 0;

    return task;
}
@}


Структура машины исполняющий байткод или native-код danmakufu:
@d danmakufu.h structs @{
struct DanmakufuMachine {
    int type;
    intptr_t *code;
    int code_size;

    DanmakufuTask *tasks;
    DanmakufuTask *last_task;

    DanmakufuDict *global;
};

typedef struct DanmakufuMachine DanmakufuMachine;
@}
По сути DanmakufuMachine -- это script_xxx + макросы в заголовке
type - тип кода(bytecode, native)
code - байткод(похож на forth)
code_size - размер байткода
tasks - указатель на список задач; last_task - последняя задача в списке,
  чтобы легче было вставлять первую в конец.
global - словарь слов-символов forth-машины(содержит переменные, имена функций итд)
  TODO: *global[32] - как насчёт хеширования?


Функции для danmakufu script версии 2:
@d danmakufu.c functions @{
@<danmakufu.c danmakufu v2 functions@>
@}

@d danmakufu.c functions @{
static void add_danmakufu_v2_funcs_to_dict(DanmakufuDict **dict) {
    DanmakufuDict *t;
    @<add_danmakufu_v2_funcs_to_dict functions@>
}
@}

Нестандартные функции для danmakufu:
@d danmakufu.c functions @{
@<danmakufu.c danmakufu my functions@>@}

@d danmakufu.c functions @{
static void add_danmakufu_my_funcs_to_dict(DanmakufuDict **dict) {
    DanmakufuDict *t;
    @<add_danmakufu_my_funcs_to_dict functions@>
}
@}

Функция загрузки скрипта:
@d danmakufu.h prototypes @{
DanmakufuMachine *danmakufu_load_file(char *filename, void *script_object);
@}

@d danmakufu.c functions @{
DanmakufuMachine *danmakufu_load_file(char *filename, void *script_object) {
    AstCons *cons = danmakufu_parse(filename);
    if(cons == NULL) {
        fprintf(stderr, "\ndanmakufu_parse error\n");
        exit(1);
    }

    DanmakufuMachine *machine = malloc(sizeof(DanmakufuMachine));
    if(machine == NULL) {
        fprintf(stderr, "\nCan't allocate memory for danmakufu_machine\n");
        exit(1);
    }

    machine->type = danmakufu_bytecode;
    machine->code = danmakufu_compile_to_bytecode(cons, &machine->code_size);

    ast_free_recursive(cons);
    cons = NULL;

    machine->tasks = NULL;
    machine->last_task = NULL;

    machine->global = NULL;

    DanmakufuDict *d = intern_to_dict(&machine->global, ast_add_symbol_to_tbl("@script_object"));
    d->ptr = script_object;


    add_danmakufu_v2_funcs_to_dict(&machine->global);
    add_danmakufu_my_funcs_to_dict(&machine->global);


    danmakufu_add_task(machine, NULL);
    int stop = 0;
    while(stop == 0)
        danmakufu_run_one_iteration(machine, &stop);

    return machine;
}
@}
script_object - объект скрипта, например: персонажт, пули...
TODO: тип объекта можно определять с помощью функии использующую cons'ы. Написать её
TODO: написать обработку ошибок при парсинге скрипта



Удалить последнюю в списке задачу у виртуальной машины:
@d danmakufu.c functions @{
static void danmakufu_remove_last_task(DanmakufuMachine *machine) {
    DanmakufuTask *t = machine->last_task;
    machine->last_task = machine->last_task->prev;

    danmakufu_tasks_free(t);
    danmakufu_tasks_pool_free_to_pool();

    if(machine->last_task == NULL)
        machine->tasks = NULL;
}
@}
если больше задач нет, то tasks = NULL

Переместить задачу на которую указывает tasks в конец списка и
изменить last_tasks на неё:
@d danmakufu.c functions @{
static void danmakufu_task_to_last_task(DanmakufuMachine *machine) {
    if(machine->tasks->next == NULL)
        return;

    machine->last_task->next = machine->tasks;
    machine->tasks->prev = machine->last_task;
    machine->last_task = machine->last_task->next;
    machine->tasks = machine->tasks->next;
    machine->last_task->next = NULL;
    machine->tasks->prev = NULL;
}
@}


@d danmakufu.c stack functions @{
static void danmakufu_stack_push(DanmakufuTask *task, void *el) {
    if(task->sp == DANMAKUFU_TASK_STACK_SIZE) {
        fprintf(stderr, "\ndanmakufu_stack overflow\n");
        exit(1);
    }

    task->stack[task->sp] = el;
    task->sp++;
}
@}

@d danmakufu.c stack functions @{
static void *danmakufu_stack_pop(DanmakufuTask *task) {
    if(task->sp == 0) {
        fprintf(stderr, "\ndanmakufu_stack is empty\n");
        exit(1);
    }

    task->sp--;
    return task->stack[task->sp];
}
@}

@d danmakufu.c stack functions @{
static void danmakufu_stack_drop(DanmakufuTask *task, int num) {
    if(task->sp == num-1) {
        fprintf(stderr, "\ndanmakufu_stack doesn't have %d elements. IP: %d\n", num, task->ip);
        exit(1);
    }

    int i;
    for(i = task->sp - num; i < task->sp; i++)
        ast_free_recursive(task->stack[i]);

    task->sp -= num;
}
@}

Продублировать на стеке num последних элементов:
@d danmakufu.c stack functions @{
static void danmakufu_stack_dup(DanmakufuTask *task, int num) {
    if(task->sp == num-1) {
        fprintf(stderr, "\ndanmakufu_stack doesn't have %d elements. IP: %d\n", num, task->ip);
        exit(1);
    }

    int i;
    for(i = 0; i < num; i++)
        danmakufu_stack_push(task, ast_copy_obj(task->stack[task->sp - num]));
}
@}

@d danmakufu.c stack functions @{
static int stack_empty(DanmakufuTask *task) {
    if(task->sp == 0)
        return 1;
    return 0;
}
@}

@d danmakufu.c stack functions @{
static double danmakufu_stack_add(DanmakufuTask *task, double num) {
    if(task->sp == 0) {
        fprintf(stderr, "\ndanmakufu_stack is empty\n");
        exit(1);
    }

    AstNumber* ast_num = task->stack[task->sp - 1];
    if(ast_num->type != ast_number) {
        fprintf(stderr, "\ndanmakufu_stack_add: incorrect type\n");
        exit(1);
    }

    ast_num->number += num;

    return ast_num->number;
}
@}

@d danmakufu.c stack functions @{
static void copy_stack(DanmakufuTask *from, DanmakufuTask *to) {
    int i;
    for(i = 0; i < from->sp; i++)
        to->stack[i] = ast_copy_obj(from->stack[i]);

    to->sp = from->sp;
}
@}


@d danmakufu.c stack functions @{
static void print_stack(DanmakufuTask *task) {
    int i;

    printf("Stack (%p):", task);
    for(i = 0; i < task->sp; i++)
        printf(" "), ast_print(task->stack[i]);

    printf("\n");
}
@}

@d danmakufu.c rstack functions @{
static void danmakufu_rstack_push(DanmakufuTask *task, int pos) {
    if(task->rp == DANMAKUFU_TASK_RSTACK_SIZE) {
        fprintf(stderr, "\ndanmakufu_rstack overflow\n");
        exit(1);
    }

    task->rstack[task->rp] = pos;
    task->rp++;
}
@}

@d danmakufu.c rstack functions @{
static int danmakufu_rstack_pop(DanmakufuTask *task) {
    if(task->rp == 0) {
        fprintf(stderr, "\ndanmakufu_rstack is empty\n");
        exit(1);
    }

    task->rp--;
    return task->rstack[task->rp];
}
@}

@d danmakufu.c rstack functions @{
static int rstack_empty(DanmakufuTask *task) {
    if(task->rp == 0)
        return 1;
    return 0;
}
@}

@d danmakufu.c rstack functions @{
static void print_rstack(DanmakufuTask *task) {
    int i;

    printf("RStack (%p):", task);
    for(i = 0; i < task->rp; i++)
        printf(" %d", task->rstack[i]);

    printf("\n");
}
@}


Выполнить последний task. Вернёт 1, если task выполнился до конца:
@d danmakufu.c functions @{
static int danmakufu_eval_last_task(DanmakufuMachine *machine) {
    DanmakufuTask *t = machine->last_task;

    while(1) {
        if(t->ip == machine->code_size)
            return 1;

        switch(machine->code[t->ip]) {
        @<danmakufu.c eval_last_task -- bytecodes@>
        case bc_decl: {
            t->ip++;
            if(danmakufu_dict_find_symbol(t->local->dict, (AstSymbol*)machine->code[t->ip]) == NULL)
                t->local->dict = danmakufu_dict_create(t->local->dict,
                                                       (AstSymbol*)machine->code[t->ip]);
            t->ip++;
            break;
        }
        case bc_scope_push: {
            t->local = danmakufu_dict_list_create(t->local);
            t->ip++;
            break;
        }
        case bc_scope_pop: {
            DanmakufuDictList *d = t->local;
            t->local = t->local->next;
            danmakufu_dict_lists_free(d);
            t->ip++;
            break;
        }
        case bc_goto: {
            t->ip++;
            t->ip = machine->code[t->ip];
            break;
        }
        case bc_if: {
            t->ip++;
            AstNumber *ast_num = danmakufu_stack_pop(t);
            if(ast_num->type != ast_number) {
                fprintf(stderr, "\nbc_if: incorrect type\n");
                exit(1);
            }

            double number = ast_num->number;

            ast_free_recursive(ast_num);
            ast_num = NULL;

            if(number == ast_true->number)
                t->ip++;
            else
                t->ip = machine->code[t->ip];
            break;
        }
        case bc_make_array: {
            t->ip++;
            int len = machine->code[t->ip];
            t->ip++;
            AstArray *arr = ast_add_arrays(len);

            int i;
            for(i = len-1; i > -1; i--)
                arr->arr[i] = danmakufu_stack_pop(t);

            danmakufu_stack_push(t, arr);
            break;
        }
        case bc_yield:
            t->ip++;
            return 0;
        case bc_inc:
            t->ip++;
            danmakufu_stack_add(t, 1);
            break;
        case bc_dec:
            t->ip++;
            danmakufu_stack_add(t, -1);
            break;
        default: {
            void *obj = (void*)machine->code[t->ip];
            int type = ((AstSymbol*)obj)->type;

            t->ip++;

            if(type == ast_symbol) {
                AstSymbol *symb = obj;

                DanmakufuDict *d = danmakufu_dict_list_find_symbol(t->local, symb);
                if(d == NULL) {
                    d = danmakufu_dict_find_symbol(machine->global, symb);
                    if(d == NULL) {
                        fprintf(stderr, "\n%s is unknown symbol\n", symb->name);
                        exit(1);
                    }
                }

                obj = d->ptr;

                if(obj == NULL) {
                    fprintf(stderr, "\n%s is unbound\n", symb->name);
                    exit(1);
                }

                type = ((AstSymbol*)obj)->type;

                @<danmakufu_eval_last_task fix functions into bytecode@>
            }

            if(type == ast_cfunction)
                ((AstCFunction*)obj)->func(machine);
            else if(type == ast_function) {
                danmakufu_rstack_push(t, t->ip);
                t->ip = ((AstFunction*)obj)->p;
            }
            else if(type == ast_number ||
                    type == ast_character ||
                    type == ast_array)
                danmakufu_stack_push(t, ast_copy_obj(obj));
        }
        }
    }

    return 0;
}
@}

@d danmakufu.c eval_last_task -- bytecodes
@{case bc_defun: {
    t->ip++;

    DanmakufuDict *d = danmakufu_dict_list_find_symbol(t->local,
                                                       (AstSymbol*)machine->code[t->ip]);
    if(d == NULL) {
        d = danmakufu_dict_find_symbol(machine->global, (AstSymbol*)machine->code[t->ip]);
        if(d == NULL) {
            machine->global = danmakufu_dict_create(machine->global,
                                                    (AstSymbol*)machine->code[t->ip]);
            d = machine->global;
        }
    }

    t->ip++;
    int after_func = machine->code[t->ip];
    t->ip++;
    ast_free_recursive(d->ptr);
    d->ptr = ast_add_functions(t->ip);
    t->ip = after_func;
    break;
}
@}

@d danmakufu.c eval_last_task -- bytecodes
@{case bc_drop: {
    danmakufu_stack_drop(t, 1);
    t->ip++;
    break;
}
case bc_2drop: {
    danmakufu_stack_drop(t, 2);
    t->ip++;
    break;
}
case bc_dup: {
    danmakufu_stack_dup(t, 1);
    t->ip++;
    break;
}
case bc_2dup: {
    danmakufu_stack_dup(t, 2);
    t->ip++;
    break;
}
@}

@d danmakufu.c eval_last_task -- bytecodes
@{case bc_setq: {
    // X <- Y
    AstSymbol *X = danmakufu_stack_pop(t);
    void *Y = danmakufu_stack_pop(t);

    if(X->type != ast_symbol) {
        fprintf(stderr, "\nin bc_setq -- X isn't symbol\n");
        exit(1);
    }

    DanmakufuDict *d = danmakufu_dict_list_find_symbol(t->local, X);
    if(d == NULL) {
        d = danmakufu_dict_find_symbol(machine->global, X);
        if(d == NULL) {
            machine->global = danmakufu_dict_create(machine->global, X);
            d = machine->global;
        }
    }

    ast_free_recursive(d->ptr);
    d->ptr = Y;

    t->ip++;
    break;
}
@}
при присваивании элемент не копируется, копируется при вставке в стек

@d danmakufu.c eval_last_task -- bytecodes
@{case bc_lit: {
    t->ip++;
    danmakufu_stack_push(t, ast_copy_obj((void*)machine->code[t->ip]));
    t->ip++;
    break;
}
@}
bc_lit помещает в стек сырые данные. То есть их не надо заворачивать в ast_number,
  потому что само это число уже может быть ast_number

@d danmakufu.c eval_last_task -- bytecodes
@{case bc_repeat: {
    t->ip++;

    double number = danmakufu_stack_add(t, -1);

    if(number == -1.0) {
        danmakufu_stack_drop(t, 1);
        t->ip = machine->code[t->ip];
    } else
        t->ip++;

    break;
}
@}

@d danmakufu.c eval_last_task -- bytecodes
@{case bc_fork: {
    t->ip++;

    DanmakufuTask *new_task = danmakufu_create_new_task(machine->tasks);
    if(machine->tasks == NULL)
        machine->last_task = new_task;
    machine->tasks = new_task;

    danmakufu_dict_list_clear(new_task->local);
    new_task->local = copy_dict_list(t->local);

    copy_stack(t, new_task);
    new_task->ip = t->ip + 1;

    t->ip += machine->code[t->ip];

    return 0;
    break;
}
@}
если после fork'а должна выполняться текущая задача, а не дочерняя, то стересть return 0
В данный момент копируется весь скоп, а не последний.

@d danmakufu.c eval_last_task -- bytecodes
@{case bc_ret: {
    if(rstack_empty(t))
        return 1;
    t->ip = danmakufu_rstack_pop(t);
    break;
}
@}

Не совсем правильный, но простой способ немного ускорить код в циклах:
@d danmakufu_eval_last_task fix functions into bytecode @{
// if(type == ast_cfunction || type == ast_function)
//     machine->code[t->ip-1] = (intptr_t)ast_copy_obj(obj);
@}
правильно было бы патчить код во время генерации, а не исполнения. Но и так
  тоже подойдёт(убедиться, что code копируется)

Выполнить одну итерацию байткода:
@d danmakufu.h prototypes @{
void danmakufu_run_one_iteration(DanmakufuMachine *machine, int *stop_flag);
@}
одна итерация - понятие растяжимое, danmakufu_run_one_iteration может вернуть
  выполнение в любой момент.
stop_flag - установка в 1 означает, что скрипт завершился и выполнять больше
  нечего.

@d danmakufu.c functions @{
void danmakufu_run_one_iteration(DanmakufuMachine *machine, int *stop_flag) {
    if(machine->tasks == NULL) {
        *stop_flag = 1;
        return;
    }

    danmakufu_task_to_last_task(machine);
    if(danmakufu_eval_last_task(machine))
        danmakufu_remove_last_task(machine);
}
@}

Создать новый task:
@d danmakufu.h prototypes @{
int danmakufu_add_task(DanmakufuMachine *machine, const char *func_name);
@}
func_name - имя функции с которой начнёт выполняться task. Скорее всего оно
  начинается на '@'. Если func_name == NULL, то начнёт выполняться с первой позиции
  байткода.
возвращает 1, если функция не найдена

@d danmakufu.c functions @{
int danmakufu_add_task(DanmakufuMachine *machine, const char *func_name) {
    DanmakufuTask *new_task = danmakufu_create_new_task(machine->tasks);

    if(func_name != NULL) {
        AstSymbol *symb = ast_add_symbol_to_tbl(func_name);
        DanmakufuDict *d = danmakufu_dict_find_symbol(machine->global, symb);
        if(d == NULL)
            return 1;

        AstFunction *func = d->ptr;

        if(func->type != ast_function) {
            fprintf(stderr, "\ndanmakufu_add_task: incorrect type\n");
            exit(1);
        }

        new_task->ip = func->p;
    }

    if(machine->tasks == NULL)
        machine->last_task = new_task;
    machine->tasks = new_task;

    return 0;
}
@}
FIXME: утечка task при возвращении 1


@d danmakufu.h prototypes @{
void danmakufu_free_machine(DanmakufuMachine *machine);
@}

@d danmakufu.c functions @{
void danmakufu_free_machine(DanmakufuMachine *machine) {
    if(machine == NULL)
        return;

    //free(machine->code);
    machine->code = NULL;

    while(machine->last_task)
        danmakufu_remove_last_task(machine);

    danmakufu_dict_clear(machine->global);
    machine->global = NULL;

    free(machine);
}
@}


@d danmakufu.c danmakufu v2 functions @{
static void v2_gt(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_gt: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y->number > X->number ? ast_copy_obj(ast_true)
                                                    : ast_copy_obj(ast_false));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl(">"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_gt);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_lt(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_lt: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y->number < X->number ? ast_copy_obj(ast_true)
                                                    : ast_copy_obj(ast_false));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("<"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_lt);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_ge(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_ge: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y->number >= X->number ? ast_copy_obj(ast_true)
                                                     : ast_copy_obj(ast_false));
    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl(">="));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_ge);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_le(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_le: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y->number <= X->number ? ast_copy_obj(ast_true)
                                                     : ast_copy_obj(ast_false));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("<="));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_le);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_add(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_add: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(Y->number + X->number));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("add"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_add);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_subtract(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_subtract: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(Y->number - X->number));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("subtract"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_subtract);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_multiply(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_multiply: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(Y->number * X->number));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("multiply"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_multiply);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_divide(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_divide: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(Y->number / X->number));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("divide"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_divide);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_remainder(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_remainder: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number((int)Y->number % (int)X->number));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("remainder"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_remainder);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_successor(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    danmakufu_stack_add(cur, 1);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("successor"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_successor);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_predcessor(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    danmakufu_stack_add(cur, -1);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("predcessor"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_predcessor);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_power(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_power: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(pow(Y->number, X->number)));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("power"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_power);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_concatenate(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstArray *X = danmakufu_stack_pop(cur);
    AstArray *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_array || Y->type != ast_array) {
        fprintf(stderr, "\nv2_concatenate: incorrect type\n");
        exit(1);
    }

    Y->arr = (void**)realloc(Y->arr, (X->len + Y->len)*sizeof(void*));
    memcpy(&(Y->arr[Y->len]), X->arr, X->len*sizeof(void*));
    Y->len = X->len + Y->len;

    free(X->arr);
    X->arr = NULL;
    X->len = 0;

    ast_free_recursive(X);

    danmakufu_stack_push(cur, Y);
}
@}
X удаляется из стека и поэтому его элементы можно перебросить в Y без копирования

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("concatenate"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_concatenate);@}

@d danmakufu.c danmakufu v2 functions @{
static int equalp_helper(void *x, void *y) {
    AstNumber *X = x;
    AstNumber *Y = y;

    if(X->type == Y->type)
        switch(X->type) {
        case ast_symbol:
            if(X == Y)
                return 1;
            return 0;
        case ast_array: {
            AstArray *A = (AstArray*)X;
            AstArray *B = (AstArray*)Y;

            if(A->len != B->len)
                return 0;

            int i;
            for(i = 0; i < A->len; i++)
                if(equalp_helper(A->arr[i], B->arr[i]) == 0)
                    return 0;
            return 1;
        }
        case ast_character: {
            AstCharacter *A = (AstCharacter*)X;
            AstCharacter *B = (AstCharacter*)Y;

            if(A->len != B->len)
                return 0;

            int i;
            for(i = 0; i < A->len; i++)
                if(A->bytes[i] != B->bytes[i])
                    return 0;
            return 1;
        }
        case ast_number: {
            if(X->number == Y->number)
                return 1;
            return 0;
        }
        case ast_cons: {
            AstCons *A = (AstCons*)X;
            AstCons *B = (AstCons*)Y;

            if(equalp_helper(A->car, B->car) &&
               equalp_helper(A->cdr, B->cdr))
                return 1;
            return 0;
        }
        }
    return 0;
}

static void v2_equalp(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    void *X = danmakufu_stack_pop(cur);
    void *Y = danmakufu_stack_pop(cur);

    AstNumber *ret = equalp_helper(X, Y) ? ast_true : ast_false;

    danmakufu_stack_push(cur, ast_copy_obj(ret));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("equalp"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_equalp);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_index(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstArray *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_array) {
        fprintf(stderr, "\nv2_index: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, Y->arr[(int)X->number]);

    Y->arr[(int)X->number] = NULL;
    ast_free_recursive(Y);

    ast_free_recursive(X);
}
@}
FIXME: уж очень жуткий костыль с занулением элемента для удаления всех кроме него

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("index"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_index);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_index_set(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstSymbol *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);
    void *Z = danmakufu_stack_pop(cur);

    if(X->type != ast_symbol || Y->type != ast_number) {
        fprintf(stderr, "\nv2_index: incorrect type Y\n");
        exit(1);
    }

    DanmakufuDict *d = danmakufu_dict_list_find_symbol(cur->local, X);
    if(d == NULL) {
        d = danmakufu_dict_find_symbol(machine->global, X);
        if(d == NULL) {
            fprintf(stderr, "\nv2_index: Isn't interned symbol\n");
            exit(1);
        }
    }

    AstArray *arr = d->ptr;
    if(arr->type != ast_array) {
        fprintf(stderr, "\nv2_index: incorrect type arr\n");
        exit(1);
    }

    int ind = (int)Y->number;
    ast_free_recursive(Y);

    if(ind >= arr->len || ind < 0) {
        fprintf(stderr, "\nv2_index: out range\n");
        exit(1);
    }

    ast_free_recursive(arr->arr[ind]);
    arr->arr[ind] = Z;
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("index!"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_index_set);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_length(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstArray *X = danmakufu_stack_pop(cur);

    if(X->type != ast_array) {
        fprintf(stderr, "\nv2_length: incorrect type\n");
        exit(1);
    }

    danmakufu_stack_push(cur, ast_add_number(X->len));

    ast_free_recursive(X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("length"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_length);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_erase(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstArray *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_array) {
        fprintf(stderr, "\nv2_erase: incorrect type\n");
        exit(1);
    }

    int ind = (int)X->number;
    ast_free_recursive(X);

    if(ind >= Y->len || ind < 0) {
        fprintf(stderr, "\nv2_erase: out range\n");
        exit(1);
    }

    ast_free_recursive(Y->arr[ind]);

    int i;
    for(i = ind+1; i < Y->len; i++)
        Y->arr[i-1] = Y->arr[i];
    Y->len--;

    danmakufu_stack_push(cur, Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("erase"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_erase);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_or(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_or: incorrect type\n");
        exit(1);
    }

    int a = equalp_helper(X, ast_true);
    int b = equalp_helper(Y, ast_true);

    danmakufu_stack_push(cur, ast_copy_obj((a || b) ? ast_true : ast_false));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("or"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_or);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_and(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_and: incorect type\n");
        exit(1);
    }

    int a = equalp_helper(X, ast_true);
    int b = equalp_helper(Y, ast_true);

    danmakufu_stack_push(cur, ast_copy_obj((a && b) ? ast_true : ast_false));

    ast_free_recursive(X);
    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("and"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_and);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_not(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_not: incorrect type\n");
        exit(1);
    }

    int a = equalp_helper(X, ast_true);

    danmakufu_stack_push(cur, ast_copy_obj(!a ? ast_true : ast_false));

    ast_free_recursive(X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("not"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_not);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_slice(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);
    AstArray *Z = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number || Z->type != ast_array) {
        fprintf(stderr, "\nv2_slice: incorrect type\n");
        exit(1);
    }

    int ind1 = (int)X->number;
    int ind2 = (int)Y->number;
    ast_free_recursive(X);
    ast_free_recursive(Y);

    if(ind1 >= Z->len || ind1 < 0) {
        fprintf(stderr, "\nv2_erase: out range\n");
        exit(1);
    }

    if(ind2 >= Z->len || ind2 < 0 || ind1 < ind2) {
        fprintf(stderr, "\nv2_erase: out range\n");
        exit(1);
    }

    AstArray *new = ast_add_arrays(ind1 - ind2);

    int i;
    for(i = ind2; i < ind1; i++) {
        new->arr[i-ind2] = Z->arr[i];
        Z->arr[i] = NULL;
    }

    ast_free_recursive(Z);

    danmakufu_stack_push(cur, new);
}
@}
FIXME: костыль с удалением как и в v2_index

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("slice"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_slice);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_negative(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_negative: incorrect type\n");
        exit(1);
    }

    X->number = -(X->number);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("negative"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_negative);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_absolute(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_absolute: incorrect type\n");
        exit(1);
    }

    X->number = abs(X->number);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("absolute"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_absolute);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_cos(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_cos: incorrect type\n");
        exit(1);
    }

    const double deg2rad = M_PI/180.0;
    X->number = cos(X->number * deg2rad);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("cos"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_cos);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_sin(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_sin: incorrect type\n");
        exit(1);
    }

    const double deg2rad = M_PI/180.0;
    X->number = sin(X->number * deg2rad);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("sin"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_sin);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_tan(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_tan: incorrect type\n");
        exit(1);
    }

    const double deg2rad = M_PI/180.0;
    X->number = tan(X->number * deg2rad);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("tan"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_tan);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_acos(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_acos: incorrect type\n");
        exit(1);
    }

    const double rad2deg = 180.0/M_PI;
    X->number = acos(X->number)*rad2deg;
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("acos"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_acos);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_asin(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_asin: incorrect type\n");
        exit(1);
    }

    const double rad2deg = 180.0/M_PI;
    X->number = asin(X->number)*rad2deg;
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("asin"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_asin);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_atan(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_atan: incorrect type\n");
        exit(1);
    }

    const double rad2deg = 180.0/M_PI;
    X->number = atan(X->number)*rad2deg;
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("atan"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_atan);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_atan2(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_atan2: incorrect type\n");
        exit(1);
    }

    const double rad2deg = 180.0/M_PI;
    X->number = atan2(Y->number, X->number)*rad2deg;
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("atan2"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_atan2);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_log(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_log: incorrect type\n");
        exit(1);
    }

    X->number = log(X->number);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("log"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_log);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_log10(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_log10: incorrect type\n");
        exit(1);
    }

    X->number = log10(X->number);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("log10"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_log10);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_rand(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_rand: incorrect type\n");
        exit(1);
    }

    AstNumber *min = Y->number < X->number ? Y : X;
    AstNumber *max = Y->number >= X->number ? Y : X;

    double rnd = ((double)rand())/RAND_MAX;
    X->number = (max->number - min->number) * rnd + min->number;
    danmakufu_stack_push(cur, X);

    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("rand"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_rand);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_rand_int(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);
    AstNumber *Y = danmakufu_stack_pop(cur);

    if(X->type != ast_number || Y->type != ast_number) {
        fprintf(stderr, "\nv2_rand_int: incorrect type\n");
        exit(1);
    }

    AstNumber *min = Y->number < X->number ? Y : X;
    AstNumber *max = Y->number >= X->number ? Y : X;

    X->number = rand()%(int)(max->number - min->number) + (int)min->number;
    danmakufu_stack_push(cur, X);

    ast_free_recursive(Y);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("rand_int"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_rand_int);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_truncate(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_truncate: incorrect type\n");
        exit(1);
    }

    X->number = trunc(X->number);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("truncate"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_truncate);
t = intern_to_dict(dict, ast_add_symbol_to_tbl("trunc"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_truncate);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_round(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_round: incorrect type\n");
        exit(1);
    }

    X->number = round(X->number);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("round"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_round);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_ceil(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_ceil: incorrect type\n");
        exit(1);
    }

    X->number = ceil(X->number);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("ceil"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_ceil);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_floor(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_floor: incorrect type\n");
        exit(1);
    }

    X->number = floor(X->number);
    danmakufu_stack_push(cur, X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("floor"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_floor);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_ToString(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_ToString: incorrect type\n");
        exit(1);
    }

    char buf[100];
    sprintf(buf, "%f", X->number);

    ast_free_recursive(X);

    danmakufu_stack_push(cur, ast_latin_string(buf));
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("ToString"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_ToString);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_CreateEnemyFromFile(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    void *user_arg = danmakufu_stack_pop(cur);
    AstNumber *direction = danmakufu_stack_pop(cur);
    AstNumber *velocity = danmakufu_stack_pop(cur);
    AstNumber *y = danmakufu_stack_pop(cur);
    AstNumber *x = danmakufu_stack_pop(cur);
    AstArray *path = danmakufu_stack_pop(cur);

    if(path->type != ast_array || x->type != ast_number || y->type != ast_number ||
       velocity->type != ast_number || direction->type != ast_number) {
        fprintf(stderr, "\nv2_CreateEnemyFromFile: incorrect type\n");
        exit(1);
    }

    char *str = ast_char_from_array(path);

    int i;
    for(i = 1; i < strlen(str); i++)
    if(str[i] == '\\')
        str[i] = '/';
/*
    character_danmakufu_v2_create(str,
                                  x->number, y->number,
                                  velocity->number, direction->number,
                                  user_arg);*/

    ast_free_recursive(x);
    ast_free_recursive(y);
    ast_free_recursive(velocity);
    ast_free_recursive(direction);
    ast_free_recursive(path);
    // ast_free_recursive(user_arg);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("CreateEnemyFromFile"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_CreateEnemyFromFile);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_SetLife(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_SetLife: incorrect type\n");
        exit(1);
    }

    DanmakufuDict *d = danmakufu_dict_find_symbol(machine->global,
                                                  ast_add_symbol_to_tbl("@script_object"));
    if(d == NULL) {
        fprintf(stderr, "\nv2_SetLife: @script_object\n");
        exit(1);
    }

    CharacterList *character = d->ptr;
    character->hp = (int)X->number;

    ast_free_recursive(X);
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("SetLife"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_SetLife);@}
"The argument of the first instance of SetLife in each enemy script (even if it is in comments) is used in plural-scripts to determine the relative lengths of the health bars" из wiki




@d danmakufu.c danmakufu v2 functions @{
static void v2_SetPlayerX(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;
/*
    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_SetPlayerX: incorrect type\n");
        exit(1);
    }

    DanmakufuDict *d = danmakufu_dict_find_symbol(machine->global,
                                                  ast_add_symbol_to_tbl("@script_object"));
    if(d == NULL) {
        fprintf(stderr, "\nv2_SetPlayerX: @script_object\n");
        exit(1);
    }

    CharacterList *character = d->ptr;
    character->x = (int)X->number;*/
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("SetPlayerX"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_SetPlayerX);@}

@d danmakufu.c danmakufu v2 functions @{
static void v2_SetPlayerY(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;
/*
    AstNumber *X = danmakufu_stack_pop(cur);

    if(X->type != ast_number) {
        fprintf(stderr, "\nv2_SetPlayerY: incorrect type\n");
        exit(1);
    }

    DanmakufuDict *d = danmakufu_dict_find_symbol(machine->global,
                                                  ast_add_symbol_to_tbl("@script_object"));
    if(d == NULL) {
        fprintf(stderr, "\nv2_SetPlayerY: @script_object\n");
        exit(1);
    }

    CharacterList *character = d->ptr;
    character->y = (int)X->number;*/
}
@}

@d add_danmakufu_v2_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("SetPlayerY"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(v2_SetPlayerY);@}




Напечатать элемент из ast:
@d danmakufu.c danmakufu my functions @{
static void my_print(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    void *X = danmakufu_stack_pop(cur);

    ast_print(X);
    printf("\n");

    ast_free_recursive(X);
}
@}

@d add_danmakufu_my_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("special_print"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(my_print);@}

@d danmakufu.c danmakufu my functions @{
static void my_stack(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    print_stack(cur);
}
@}

@d add_danmakufu_my_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("special_stack"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(my_stack);@}

@d danmakufu.c danmakufu my functions @{
static void my_rstack(void *arg) {
    DanmakufuMachine *machine = arg;
    DanmakufuTask *cur = machine->last_task;

    print_rstack(cur);
}
@}

@d add_danmakufu_my_funcs_to_dict functions @{
t = intern_to_dict(dict, ast_add_symbol_to_tbl("special_rstack"));
ast_free_recursive(t->ptr);
t->ptr = ast_add_cfunctions(my_rstack);@}


===========================================================

Персонажи(в терминах dmf enemies)

@d Character types
@{character_danmakufu_v2,
@}


@d Character public prototypes
@{CharacterList *character_danmakufu_v2_create(char *filename,
                                               int begin_x, int begin_y,
                                               int velocity, int direction,
                                               void *user_arg);
@}

@d Character functions @{
CharacterList *character_danmakufu_v2_create(char *filename,
                                             int begin_x, int begin_y,
                                             int velocity, int direction,
                                             void *user_arg) {
    CharacterList *character = character_get_free_cell();

    character->x = begin_x;
    character->y = begin_y;
    character->hp = 100;
    character->character_type = character_danmakufu_v2;
    character->radius = 10;

    character->args[CMA(danmakufu_v2, time_point_for_movement_x)] = 0;
    character->args[CMA(danmakufu_v2, time_point_for_movement_y)] = 0;

    character->args[CMA(danmakufu_v2, move_x)] = to_x;
    character->args[CMA(danmakufu_v2, move_y)] = to_y;

    character->args[CMA(danmakufu_v2, last_horizontal)] = 0;
    character->args[CMA(danmakufu_v2, movement_animation)] = 0;

    character->args[CMA(danmakufu_v2, speed)] = 0;

    character->args[CMA(danmakufu_v2, step_of_movement)] = 0;

    character->args[CMA(danmakufu_v2, move_percent)] = 0;
    character->args[CMA(danmakufu_v2, move_begin_x)] = 0;
    character->args[CMA(danmakufu_v2, move_begin_y)] = 0;

    character->args[CMA(danmakufu_v2, time)] = 0;

    DanmakufuMachine *machine = danmakufu_load_file(filename, character);
    character->args[CMA(danmakufu_v2, danmakufu_machine)] = machine;

    DanmakufuDict *d = intern_to_dict(&machine->global, ast_add_symbol_to_tbl("@user_arg"));
    ast_free_recursive(d->ptr);
    d->ptr = ast_copy_obj(user_arg);

    int stop = 0;
    if(danmakufu_add_task(machine, "@Initialize") == 0) {
        stop = 0;
        while(stop == 0)
            danmakufu_run_one_iteration(machine, &stop);
    }

    return character;
}
@}
user_arg - объект из ast для передачи в другой скрипт

@d Character public structs @{
enum {
    CMA(danmakufu_v2, danmakufu_machine) = 0,
    CMA(danmakufu_v2, time_point_for_movement_x),
    CMA(danmakufu_v2, time_point_for_movement_y),
    CMA(danmakufu_v2, move_x),
    CMA(danmakufu_v2, move_y),
    CMA(danmakufu_v2, last_horizontal),
    CMA(danmakufu_v2, movement_animation),
    CMA(danmakufu_v2, speed),
    CMA(danmakufu_v2, step_of_movement),
    CMA(danmakufu_v2, move_percent),
    CMA(danmakufu_v2, move_begin_x),
    CMA(danmakufu_v2, move_begin_y),
    CMA(danmakufu_v2, time)
};
@}

@d character_set_weak_time_point_x other characters
@{case character_danmakufu_v2:
    character_danmakufu_v2_set_weak_time_point_x(character);
    break;
@}

@d character_set_weak_time_point_y other characters
@{case character_danmakufu_v2:
    character_danmakufu_v2_set_weak_time_point_y(character);
    break;
@}

Добавление time points с возможностью изменять скорость:
@d Different characters set weak time_point functions @{
static void character_danmakufu_v2_set_weak_time_point_x(CharacterList *character) {
    character->args[CMA(danmakufu_v2, time_point_for_movement_x)] = 30;
}

static void character_danmakufu_v2_set_weak_time_point_y(CharacterList *character) {
    character->args[CMA(danmakufu_v2, time_point_for_movement_y)] = 30;
}
@}

Функции обновления time points:
@d characters_update_all_time_points other characters
@{case character_danmakufu_v2:
    character_danmakufu_v2_update_time_points(character);
    break;
@}

@d Update time point for different characters @{
static void character_danmakufu_v2_update_time_points(CharacterList *character) {
    if(character->args[CMA(danmakufu_v2, time_point_for_movement_x)] > 0)
        character->args[CMA(danmakufu_v2, time_point_for_movement_x)]--;

    if(character->args[CMA(danmakufu_v2, time_point_for_movement_y)] > 0)
        character->args[CMA(danmakufu_v2, time_point_for_movement_y)]--;

    character->args[CMA(danmakufu_v2, movement_animation)]++;
}
@}
Меняем и movement_animation


@d characters_ai_control other characters
@{case character_danmakufu_v2:
    character_danmakufu_v2_ai_control(character);
    break;
@}

@d AI functions for different characters @{
static void character_danmakufu_v2_ai_control(CharacterList *character) {
    int *const move_x = &character->args[CMA(danmakufu_v2, move_x)];
    int *const move_y = &character->args[CMA(danmakufu_v2, move_y)];
    int *const end_x = &character->args[CMA(danmakufu_v2, end_x)];
    int *const end_y = &character->args[CMA(danmakufu_v2, end_y)];
    int *const speed = &character->args[CMA(danmakufu_v2, speed)];
    int *const step_of_movement = &character->args[CMA(danmakufu_v2, step_of_movement)];
    int *const move_percent = &character->args[CMA(danmakufu_v2, move_percent)];
    int *const time = &character->args[CMA(danmakufu_v2, time)];


}
@}

@d characters_draw other characters
@{case character_danmakufu_v2:
    character_danmakufu_v2_draw(character);
    break;
@}

@d Draw functions for different characters @{
static void character_danmakufu_v2_draw(CharacterList *character) {
    int *const move_x = &character->args[CMA(danmakufu_v2, move_x)];
    int *const last_horizontal = &character->args[CMA(danmakufu_v2, last_horizontal)];
    int *const movement_animation = &character->args[CMA(danmakufu_v2, movement_animation)];

    static int id = -1;

    if(id == -1)
        id = image_load("blue_fairy.png");

}
@}


Повреждение от пуль:
@d damage_calculate other enemy characters
@{case character_danmakufu_v2:
    if(bullet->bullet_type == bullet_reimu_first)
        character->hp -= 1000;
    break;
@}


===========================================================

