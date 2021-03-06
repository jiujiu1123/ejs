#lang racket/base

(provide equal-ejsexprs?
         property-value
         has-property?
         object-values
         remove-property)

(require (only-in racket/list
                  empty?
                  first
                  rest)
         (only-in racket/set
                  list->set
                  set=?)
         racket/contract
         (file "./value.rkt"))

(module+ test
  (require rackunit))

(define/contract (has-property? obj prop)
  (ejs-object? (or/c symbol? string?) . -> . boolean?)
  (cond [(symbol? prop)
         (hash-has-key? obj prop)]
        [else
         (hash-has-key? obj (string->symbol prop))]))

(module+ test
  (let ([obj (hasheq 'foo "bar")])
    (check-true (ejs-object? obj))
    (check-true (has-property? obj 'foo))
    (check-true (has-property? obj "foo"))
    (check-false (has-property? obj 'bar))))

(define/contract (property-value obj prop)
  (ejs-object? (or/c symbol? string?) . -> . ejsexpr?)
  (cond [(symbol? prop)
         (hash-ref obj prop)]
        [else
         (hash-ref obj (string->symbol prop))]))



(module+ test
  (test-case "Basic JSON object check"
    (check-false (ejs-object? 5))
    (check-false (ejs-object? #t))
    (check-false (ejs-object? (list)))
    (check-true (ejs-object? (hasheq)))
    (check-true (ejs-object? (hasheq 'type "object")))))

(define/contract (object-properties obj)
  (ejs-object? . -> . (listof string?))
  (map symbol->string
       (hash-keys obj)))

(define (object-values obj)
  (hash-values obj))

(define (equal-arrays? jsarr1 jsarr2)
  (if (empty? jsarr1)
      (empty? jsarr2)
      (if (empty? jsarr2)
          #f
          (let ([a1 (first jsarr1)]
                [b1 (first jsarr2)]
                [as (rest jsarr1)]
                [bs (rest jsarr2)])
            (and (equal-ejsexprs? a1 b1)
                 (equal-arrays? as bs))))))

(define (remove-property jsobj prop)
  (hash-remove jsobj prop))

(define/contract (equal-objects? jsobj1 jsobj2)
  (ejs-object? ejs-object? . -> . boolean?)
  (define props1 (object-properties jsobj1))
  (define props2 (object-properties jsobj2))
  (and (set=? (list->set props1) (list->set props2))
       (andmap (lambda (p)
                 (equal-ejsexprs? (property-value jsobj1 p)
                                  (property-value jsobj2 p)))
               props1)))

;; assumes that both arguments are ejsexpr? values
(define/contract (equal-ejsexprs? js1 js2)
  (ejsexpr? ejsexpr? . -> . boolean?)
  (cond [(ejs-null? js1)
         (ejs-null? js2)]
        [(ejs-string? js1)
         (and (ejs-string? js2)
              (string=? js1 js2))]
        [(ejs-number? js1)
         (and (ejs-number? js2)
              (= js1 js2))]
        [(ejs-boolean? js1)
         (and (ejs-boolean? js2)
              (eq? js1 js2))]
        [(ejs-array? js1)
         (and (ejs-array? js2)
              (equal-arrays? js1 js2))]
        [(ejs-object? js1)
         (and (ejs-object? js2)
              (equal-objects? js1 js2))]))

(module+ test

  (test-case "Null equality"
    (check-true (equal-ejsexprs? 'null 'null))
    (check-false (equal-ejsexprs? 'null "null")))
  (test-case "String equality"
    (check-true (equal-ejsexprs? "dog" "dog"))
    (check-false (equal-ejsexprs? "a" "A"))
    (check-true (equal-ejsexprs? "" ""))
    (check-true (equal-ejsexprs? "düg" "d\u00fcg"))
    (check-false (equal-ejsexprs? "null" 'null)))

  (test-case "Boolean equality"
    (check-true (equal-ejsexprs? #f #f))
    (check-true (equal-ejsexprs? #t #t))
    (check-false (equal-ejsexprs? #f #t))
    (check-false (equal-ejsexprs? #t 1))
    (check-false (equal-ejsexprs? #f 0)))

  (test-case "Number equality"
    (check-true (equal-ejsexprs? #e0 #e0))
    (check-true (equal-ejsexprs? #e0 #e0.0))
    (check-false (equal-ejsexprs? #e-1 #e-0.999999999))
    (check-true (equal-ejsexprs? #e3.141592654 #e3.141592654))
    (check-false (equal-ejsexprs? #e3.141592654 #e3.141592653))
    (check-true (equal-ejsexprs? #e4 #e4.000000000000))
    (check-false (equal-ejsexprs? #e4 #e4.000000000001)))

  (test-case "Object equality"
    (check-true (equal-ejsexprs? (hasheq)
                             (hasheq)))
    (check-true (equal-ejsexprs? (hasheq 'foo "bar")
                             (hasheq 'foo "bar")))
    (check-true (equal-ejsexprs? (hasheq 'foo 'null)
                             (hasheq 'foo 'null)))
    (check-true (equal-ejsexprs? (hasheq 'a "b"
                                     'c "d")
                             (hasheq 'c "d"
                                     'a "b")))
    (check-false (equal-ejsexprs? (hasheq 'a "b"
                                      'c "d")
                              (hasheq 'a "d"
                                      'c "d")))
    (check-true (equal-ejsexprs? (hasheq 'a "düg")
                             (hasheq 'a "d\u00fcg")))
    (check-true (equal-ejsexprs? (hasheq 'a "b"
                                     'c (hasheq 'a "b"))
                             (hasheq 'a "b"
                                     'c (hasheq 'a "b"))))
    (check-true (equal-ejsexprs? (hasheq 'a "b"
                                     'c (list "a" "b"))
                             (hasheq 'c (list "a" "b")
                                     'a "b"))))

  (test-case "Array equality"
    (check-true (equal-ejsexprs? (list) (list)))
    (check-false (equal-ejsexprs? (list "a") (list)))
    (check-false (equal-ejsexprs? (list) (hasheq)))
    (check-true (equal-ejsexprs? (list "a" (hasheq 'a "b"))
                             (list "a" (hasheq 'a "b"))))
    (check-false (equal-ejsexprs? (list "a" "b")
                              (list "b" "a")))
    (check-true (equal-ejsexprs? (list (list "a" "b"))
                             (list (list "a" "b"))))))
