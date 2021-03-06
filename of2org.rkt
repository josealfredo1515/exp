#!/usr/bin/env racket
#lang racket/base
#|
 How to use this to convert OmniFocus documents to org-mode

 0. View all your tasks in OmniFocus
  
    Best way to do this: Go into Planning Mode and click on
    "Library"

 1. Click File > Export and choose OmniFocus document

    I assume you save it as ~/Desktop/OmniFocus.ofocus

 2. Open a Terminal

    cd ~/Desktop/OmniFocus.ofocus
    ls
    # There should be one Zip file
    open ${TheZip}.zip
    # There should now be one 'contents.xml' file
    ./of2org.rkt contents.xml contents.org

 3. Now rejoice that contents.org is in org-mode

|#

(require racket/cmdline
         xml
         racket/match
         xml/path
         racket/function
         racket/list
         racket/port
         (prefix-in 19: srfi/19))

(define-values
  (input output)
  (command-line
   #:program "of2org"
   #:args (input output)
   (values input output)))

(define input-xml
  (parameterize ([collapse-whitespace #t])
    (with-input-from-file input 
      read-xml)))

(define contexts (make-hash))
(struct context (parent rank name))

(define tasks (make-hash))
(struct task (parent context rank name start end repeat note))

(define (delist l)
  (apply string-append l))

(define (despace s)
  (regexp-replace* " " s ""))

(define walk
  (match-lambda
    [(struct* document ([element e]))
     (walk e)]
    [(struct* element ([name 'omnifocus] [content c]))
     (for-each walk c)]
    [(and (struct* element 
                   ([name 'context]
                    [attributes (list-no-order 
                                 (struct* attribute ([name 'id]
                                                     [value id]))
                                 _ ...)]))
          c)
     (define cx (xml->xexpr c))
     (define parent (se-path* '(context #:idref) cx))
     (define rank (string->number (se-path* '(rank) cx)))
     (define name (despace (delist (se-path*/list '(name) cx))))
     (hash-set! contexts id (context parent rank name))]
    [(and (struct* element
                   ([name 'folder]
                    [attributes (list-no-order 
                                 (struct* attribute ([name 'id]
                                                     [value id]))
                                 _ ...)]))
          f)
     (define fx (xml->xexpr f))
     (define parent (se-path* '(folder #:idref) fx))
     (define rank (string->number (se-path* '(rank) fx)))
     (define name (delist (se-path*/list '(name) fx)))
     (hash-set! tasks id (task parent #f rank name #f #f #f #f))]
    [(and (struct* element
                   ([name 'task]
                    [attributes (list-no-order 
                                 (struct* attribute ([name 'id]
                                                     [value id]))
                                 _ ...)]))
          t)
     (define tx (xml->xexpr t))
     (define context (se-path* '(context #:idref) tx))
     (define f-parent (se-path* '(folder #:idref) tx))
     (define t-parent (se-path* '(task #:idref) tx))
     (define parent
       (match* (f-parent t-parent)
               [(#f #f) #f]
               [(f #f) f]
               [(#f t) t]))
     (define name (delist (se-path*/list '(name) tx)))
     (define rank (string->number (se-path* '(rank) tx)))
     (define start (se-path* '(start) tx))
     (define end (se-path* '(due) tx))
     (define repeat (se-path* '(repeat) tx))
     (define note (se-path*/list '(note) tx))
     (unless (se-path* '(completed) tx)
       (hash-set! tasks id 
                  (task parent context rank name start end repeat 
                        note)))]
    [(or (struct* pcdata ([string " "]))
         (struct* element ([name 'setting]))
         (struct* element ([name 'perspective])))
     (void)]
    [x
     (error 'of2org "Unknown thing: ~e" x)]))

(walk input-xml)

(define (context-output c)
  (with-output-to-string
      (λ ()
        (printf ":")
        (for-each (curry printf "~a") 
                  (add-between (parent->child-context c) ":"))
        (printf ":"))))

(define (snoc l x) (append l (list x)))

(define parent->child-context
  (match-lambda
    [#f empty]
    [(app (curry hash-ref contexts)
          (struct* context ([parent p] [name n])))
     (snoc (parent->child-context p) n)]))

(define depth (make-parameter 1))
(define (*s)
  (make-string (depth) #\*))

(define (convert-time t r)
  (define gmt-d (19:string->date t "~Y-~m-~dT~H:~M:~S.000Z"))
  (define d 
    (19:time-utc->date
     (19:date->time-utc
      (let ([d gmt-d])
        (19:make-date 0 
                      (19:date-second d)
                      (19:date-minute d)
                      (19:date-hour d)
                      (19:date-day d)
                      (19:date-month d)
                      (19:date-year d)
                      0)))))
  (define o (19:date->string d "~Y-~m-~d ~a ~H:~M"))
  (match r
    [#f 
     (format "<~a>" o)]
    [(regexp #rx"^@([0-9]+[dwmy])$" (list _ spec))
     (format "<~a +~a>" o spec)]
    [(regexp #rx"^~([0-9]+[dwmy])$" (list _ spec))
     (format "<~a ++~a>" o spec)]))

(define print-lit
  (match-lambda
    [" " (void)]
    [`(style . ,x) (void)]
    [`(lit () ,@(list (? string? texts) ...))
     (for-each display texts)]
    [x (error 'print-lit "~v" x)]))
(define print-run
  (match-lambda
    [" " (void)]
    [`(run () . ,lits)
     (for-each print-lit lits)]
    [x (error 'print-run "~v" x)]))
(define print-p
  (match-lambda
    [" " (void)]
    [`(p () . ,runs)
     (printf "\t")
     (for-each print-run runs)
     (newline)]
    [x (error 'print-p "~v" x)]))
(define print-text
  (match-lambda
    [" " (void)]
    [`(text () . ,ps)
     (for-each print-p ps)]
    [x (error 'print-text "~v" x)]))
(define (print-note n)
  (for-each print-text n))

(define (output-tasks/parent the-p)
  (define these-tasks
    (for/list ([(id t) (in-hash tasks)]
               #:when (equal? the-p (task-parent t)))
              (cons id t)))
  (for ([id*t (in-list (sort these-tasks <= #:key (compose task-rank cdr)))])
       (match-define 
        (cons id 
              (and t (struct task (parent context rank name start end repeat note))))
        id*t)
       (printf "~a ~a~a\t~a\n" (*s)
               (if (or start end) "TODO  " "")
               name (context-output context))
       (when start
             (printf "SCHEDULED: ~a\n" (convert-time start repeat)))
       (when end
             (printf "DEADLINE: ~a\n" (convert-time end repeat)))
       (when note
             (print-note note)
             (newline))
       (parameterize ([depth (add1 (depth))])
                     (output-tasks/parent id))))

(with-output-to-file
    output
  #:exists 'replace
  (λ ()
    (output-tasks/parent #f)))
