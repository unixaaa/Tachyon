;;;============================================================================

;;; File: "js2scm-rt#.scm", Time-stamp: <2010-12-14 16:16:00 feeley>

;;; Copyright (c) 2010 by Marc Feeley, All Rights Reserved.

;;;============================================================================

(declare
 (standard-bindings)
 (extended-bindings)
 (not safe)
 (block)
 (not inline)
)

(define-macro (js.undefined)
  `(##void))
;  `(##type-cast -7 2)) ;; #!unbound object

;;; JavaScript forms.

(define-macro (js.var variable)
  `(define ,variable #f))

(define-macro (js.function params body)
  `(lambda (this
            #!optional
            ,@(map (lambda (p) (list p '(js.undefined))) params)
            .
            args)
     ,body))

(define-macro (js.function-with-arguments params body)
  `(lambda (this . args)
     (let* ((_arguments (list->Array args))
            ,@(map (lambda (p)
                     (list p `(if (pair? args)
                                  (let ((arg (car args)))
                                    (set! args (cdr args))
                                    arg)
                                  (js.undefined))))
                   params))
       ,body)))

(define-macro (js.function-with-nontail-return params body)
  `(lambda (this
            #!optional
            ,@(map (lambda (p) (list p '(js.undefined))) params)
            .
            args)
     (continuation-capture
      (lambda (return)
        ,body))))

(define-macro (js.function-with-nontail-return-with-arguments params body)
  `(lambda (this . args)
     (let* ((_arguments (list->Array args))
            ,@(map (lambda (p)
                     (list p `(if (pair? args)
                                  (let ((arg (car args)))
                                    (set! args (cdr args))
                                    arg)
                                  (js.undefined))))
                   params))
       (continuation-capture
        (lambda (return)
          ,body)))))

(define-macro (js.return value)
  `(continuation-return return ,value))

(define-macro (js.this)
  `this)

(define-macro (js.if test consequent alternative)
  `(if (let ((res ,test))
         (cond ((##eq? res (js.undefined))
                (error "this if test is undefined"))
               ((not (boolean? res))
                (error "this if test is not a boolean" res))
               (else
                res)))
       ,consequent
       ,alternative))

(define-macro (js.call fn . args)
  (if (and (pair? fn)
           (eq? (car fn) 'js.index))
      `(let* ((self ,(cadr fn)) (f (js.index self ,(caddr fn))))
         ((if (procedure? f) f ',fn) self ,@args))
      `(,fn '() ,@args)))

(define-macro (js.new ctor . args)
  `(let* ((ctor ,ctor)
          (self (make-Object ctor (get-prototype ctor) (make-assoc-table)))
          (retval (ctor self ,@args)))
     (if (##eq? retval (js.undefined))
         self
         retval)))

(define-macro (js.index obj field)
  `(js:index ,obj ,field))

(define-macro (js.index-set! obj field value)
  `(js:index-set! ,obj ,field ,value))

(define-macro (js.array-lit . elems)
  `(js:array-lit ,@elems))

(define-macro (js.obj-lit . props)
  `(make-Object #f #f (list->assoc-table (list ,@props))))

(define-macro (js.prop name value)
  `(cons ,name ,value))

(define-macro (js.continue)
  `(TODO-js.continue))

(define-macro (js.break)
  `(continuation-return break (void)))

(define-macro (js.switch val . clauses)
  `(let ((switch-val ,val))
     (js.switch-clauses ,@clauses)))

(define-macro (js.switch-with-break val . clauses)
  `(continuation-capture
    (lambda (break)
      (let ((val ,val))
        (js.switch-clauses ,@clauses)))))

(define-macro (js.switch-clauses . clauses)
  (if (assq 'js.case-fall-through clauses)
      (error "switch with fall-through not implemented" clauses)
      (let ()

        (define (gen clauses default-clause)
          (if (pair? clauses)
              (let* ((clause (car clauses))
                     (case-expr (cadr clause)))
                (if (equal? case-expr '(js.default))
                    (gen (cdr clauses) clause)
                    `(if (js.=== switch-val ,case-expr)
                         ,(caddr clause)
                         ,(gen (cdr clauses) default-clause))))
              (if default-clause
                  (caddr default-clause)
                  `(js.undefined))))

        (gen clauses #f))))

(define-macro (js.dowhile loop-id body test)
  `(let ,loop-id ()
     ,body
     (if ,test
         (,loop-id))))

(define-macro (js.dowhile-with-break loop-id body test)
  `(continuation-capture
    (lambda (break)
      (let ,loop-id ()
        ,body
        (if ,test
            (,loop-id))))))

(define-macro (js.while loop-id test body)
  `(let ,loop-id ()
     (if ,test
         (begin
           ,body
           (,loop-id)))))

(define-macro (js.while-with-break loop-id test body)
  `(continuation-capture
    (lambda (break)
      (let ,loop-id ()
        (if ,test
            (begin
              ,body
              (,loop-id)))))))

(define-macro (js.for loop-id test body step)
  `(let ,loop-id ()
     (if ,test
         (begin
           ,body
           ,step
           (,loop-id)))))

(define-macro (js.for-with-break loop-id test body step)
  `(continuation-capture
    (lambda (break)
      (let ,loop-id ()
        (if ,test
            (begin
              ,body
              ,step
              (,loop-id)))))))

(define-macro (js.forin loop-id lhs set body)
  `(js:forin
    ,set
    (lambda (key) (js.= ,lhs key) ,body)))

(define-macro (js.forin-with-break loop-id lhs set body)
  `(continuation-capture
    (lambda (break)
      (js.forin ,loop-id ,lhs ,set ,body))))

(define-macro (js.throw val)
  `(js:throw ,val))

(define-macro (js.try body . final-body)
  body) ;; TODO support exception handling

(define-macro (js.try-catch body id catch-body . final-body)
  body) ;; TODO support exception handling

(define-macro (js.debugger)
  `(break))

;;; JavaScript operators.

(define-macro (js.delete x)
  `(TODO-js.delete))

(define-macro (js.void x)
  `(TODO-js.void))

(define-macro (js.typeof x)
  `(js:typeof ,x))

(define-macro (js.++x x)
  (if (and (pair? x)
           (eq? (car x) 'js.index))
      `(let* ((self ,(cadr x)) (key ,(caddr x)) (res (js.+ (js.index self key) 1)))
         (js.index-set! self key res)
         res)
      `(let ((res (js.+ ,x 1)))
         (set! ,x res)
         res)))

(define-macro (js.auto++x x)
  `(TODO-js.auto++x))

(define-macro (js.--x x)
  (if (and (pair? x)
           (eq? (car x) 'js.index))
      `(let* ((self ,(cadr x)) (key ,(caddr x)) (res (js.- (js.index self key) 1)))
         (js.index-set! self key res)
         res)
      `(let ((res (js.- ,x 1)))
         (set! ,x res)
         res)))

(define-macro (js.auto--x x)
  `(TODO-js.auto--x))

(define-macro (js.~ x)
  `(TODO-js.~))

(define-macro (js.! x)
  `(let ((x ,x))
     (cond ((##eq? x (js.undefined))
            (error "js.! argument is undefined"))
           ((not (boolean? x))
            (error "js.! argument is not a boolean" x))
           (else
            (not x))))) ;; is this correct?

(define-macro (js.x++ x)
  (if (and (pair? x)
           (eq? (car x) 'js.index))
      `(let* ((self ,(cadr x)) (key ,(caddr x)) (res (js.index self key)))
         (js.index-set! self key (js.+ res 1))
         res)
      `(let ((res ,x))
         (set! ,x (js.+ res 1))
         res)))

(define-macro (js.x-- x)
  (if (and (pair? x)
           (eq? (car x) 'js.index))
      `(let* ((self ,(cadr x)) (key ,(caddr x)) (res (js.index self key)))
         (js.index-set! self key (js.- res 1))
         res)
      `(let ((res ,x))
         (set! ,x (js.- res 1))
         res)))

(define-macro (js.* x y)
  (if #t ;; assume only numerical type is fixnum and no overflow
      `(let* ((x ,x) (y ,y))
         (if (##fixnum? x)
             (if (##fixnum? y)
                 (if (fx= y 0)
                     0
                     (let ((r (##fx*? x y)))
                       (or r (js:* x y))))
                 (js:* x y))
             (js:* x y)))
      `(##fx* ,x ,y)))

(define-macro (js./ x y)
  `(/ ,x ,y));;;;;;;;;;;;;;;;;;;;;;;;;

(define-macro (js.% x y)
  `(fxmodulo ,x ,y))

(define-macro (js.+ x . y)
  (if (null? y)
      `(js.+ 0 ,x)
      (if #t
          `(let* ((x ,x) (y ,(car y)))
             (if (##fixnum? x)
                 (if (##fixnum? y)
                     (let ((r (##fx+? x y)))
                       (or r (js:+ x y)))
                     (js:+ x y))
                 (js:+ x y)))
          `(##fx+ ,x ,(car y)))))

(define-macro (js.- x . y)
  (if (null? y)
      `(js.- 0 ,x)
      (if #t ;; assume only numerical type is fixnum and no overflow
          `(let* ((x ,x) (y ,(car y)))
             (if (##fixnum? x)
                 (if (##fixnum? y)
                     (let ((r (##fx-? x y)))
                       (or r (js:- x y)))
                     (js:- x y))
                 (js:- x y)))
          `(##fx- ,x ,(car y)))))

(define-macro (js.<< x y)
  `(fxarithmetic-shift-left ,x ,y))

(define-macro (js.>> x y)
  `(fxarithmetic-shift-right ,x ,y))

(define-macro (js.>>> x y)
  `(fxarithmetic-shift-right ,x ,y));;;;;;;;;;;;;;;;;

(define-macro (js.< x y)
  (if #t ;; assume only numerical type is fixnum and no overflow
      `(let* ((x ,x) (y ,y))
         (if (##fixnum? x)
             (if (##fixnum? y)
                 (##fx< x y)
                 (js:< x y))
             (js:< x y)))
      `(##fx< ,x ,y)))

(define-macro (js.> x y)
  (if #t ;; assume only numerical type is fixnum and no overflow
      `(let* ((x ,x) (y ,y))
         (if (##fixnum? x)
             (if (##fixnum? y)
                 (##fx> x y)
                 (js:> x y))
             (js:> x y)))
      `(##fx> ,x ,y)))

(define-macro (js.<= x y)
  (if #t ;; assume only numerical type is fixnum and no overflow
      `(let* ((x ,x) (y ,y))
         (if (##fixnum? x)
             (if (##fixnum? y)
                 (##fx<= x y)
                 (js:<= x y))
             (js:<= x y)))
      `(##fx<= ,x ,y)))

(define-macro (js.>= x y)
  (if #t ;; assume only numerical type is fixnum and no overflow
      `(let* ((x ,x) (y ,y))
         (if (##fixnum? x)
             (if (##fixnum? y)
                 (##fx>= x y)
                 (js:>= x y))
             (js:>= x y)))
      `(##fx>= ,x ,y)))

(define-macro (js.instanceof x y)
  `(js:instanceof ,x ,y))

(define-macro (js.in x y)
  `(TODO-js.in))

(define-macro (js.== x y)
  (if #t ;; assume only numerical type is fixnum and no overflow
      `(let* ((x ,x) (y ,y))
         (if (##fixnum? x)
             (if (##fixnum? y)
                 (##fx= x y)
                 #f)
             (js:== x y)))
      `(##fx= ,x ,y)))

(define-macro (js.!= x y)
  (if #t ;; assume only numerical type is fixnum and no overflow
      `(let* ((x ,x) (y ,y))
         (if (##fixnum? x)
             (if (##fixnum? y)
                 (not (##fx= x y))
                 #t)
             (js:!= x y)))
      `(not (##fx= ,x ,y))))

(define-macro (js.=== x y)
  `(let* ((x ,x) (y ,y))
     (eq? x y))) ;;; is this correct?

(define-macro (js.!== x y)
  `(let* ((x ,x) (y ,y))
     (not (eq? x y)))) ;;; is this correct?

(define-macro (js.& x y)
  `(fxand ,x ,y))

(define-macro (js.^ x y)
  `(TODO-js.^))

(define-macro (|js.\|| x y)
  `(|TODO-js.\||))

(define-macro (js.&& x y)
  `(and ,x ,y))

(define-macro (|js.\|\|| x y)
  `(or ,x ,y))

(define-macro (|js.,| x y)
  `(begin ,x ,y))

(define-macro (js.= x y)
  (if (and (pair? x)
           (eq? (car x) 'js.index))
      `(let* ((self ,(cadr x)) (key ,(caddr x)) (res ,y))
         (js.index-set! self key res)
         res)
      `(let ((res ,y))
         (set! ,x res)
         res)))

(define-macro (js.+= x y)
  (if (and (pair? x)
           (eq? (car x) 'js.index))
      `(let* ((y ,y) (self ,(cadr x)) (key ,(caddr x)) (res (js.+ (js.index self key) y)))
         (js.index-set! self key res)
         res)
      `(let* ((y ,y) (res (js.+ ,x y)))
         (set! ,x res)
         res)))

(define-macro (js.-= x y)
  (if (and (pair? x)
           (eq? (car x) 'js.index))
      `(let* ((y ,y) (self ,(cadr x)) (key ,(caddr x)) (res (js.- (js.index self key) y)))
         (js.index-set! self key res)
         res)
      `(let* ((y ,y) (res (js.- ,x y)))
         (set! ,x res)
         res)))

(define-macro (js.*= x y)
  `(TODO-js.*=))

(define-macro (js./= x y)
  `(TODO-js./=))

(define-macro (js.<<= x y)
  `(TODO-js.<<=))

(define-macro (js.>>= x y)
  `(TODO-js.>>=))

(define-macro (js.>>>= x y)
  `(TODO-js.>>>=))

(define-macro (js.&= x y)
  `(TODO-js.&=))

(define-macro (js.^= x y)
  `(TODO-js.^=))

(define-macro (|js.\|=| x y)
  `(|TODO-js.\|=|))

(define-macro (js.%= x y)
  `(TODO-js.%=))

(define-macro (js.x?y:z x y z)
  `(if ,x ,y ,z))

;;;============================================================================
