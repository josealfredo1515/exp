#lang racket
(require racket/package
         net/url
         (planet neil/html-parsing/html-parsing)
         (planet clements/sxml2))

(define (los->s los)
  (regexp-replace*
   #rx"^ +"
   (regexp-replace* #rx" +$"
                    (regexp-replace* #rx"\u200B" (apply string-append los) "")
                    "")
   ""))

(define (u->jpn u-base)
  (define u (format "~a?lang=jpn" u-base))
  (define xe (call/input-url (string->url u) get-pure-port html->xexp))
  (define (get-div class)
    (first ((sxpath (format "//div[@class=~s]" class)) xe)))

  #;(pretty-print xe)

  (define subtitle-raw (list-tail (get-div "subtitle") 2))
  (define intro-raw (list-tail (get-div "intro") 2))
  (define summary-raw (rest (first (list-tail (get-div "summary") 2))))
  (define verses-xe (list '*TOP* (get-div "verses")))

  (define (simpl-verse p)
    (append-map
     (match-lambda
      [(? string? e)
       (list e)]
      [(and e (list-rest 'ruby _))
       (list e)]
      [(list 'a @s rest ...)
       rest]
      [(list-rest (or 'sup 'span) _)
       empty])
     p))

  (define (simpl-verse->expression l)
    (filter-map
     (match-lambda
      [(? string? e)
       e]
      [`(ruby ,kanji)
       kanji]
      [`(ruby (rp "(") (rt ,reading) (rp ")"))
       #f]
      [`(ruby ,kanji (rp "(") (rt ,reading) (rp ")"))
       kanji])
     l))
  (define (simpl-verse->reading l)
    (map (match-lambda
          [(? string? e)
           e]
          [`(ruby ,kanji)
           kanji]
          [`(ruby (rp "(") (rt ,reading) (rp ")"))
           (format "「~a」" reading)]
          [`(ruby ,kanji (rp "(") (rt ,reading) (rp ")"))
           (format "~a「~a」" kanji reading)])
         l))

  (define (prep-verse v)
    (list-tail v 2))
  (define (combine-verse sv)
    (define kanji (simpl-verse->expression sv))
    (define reading (simpl-verse->reading sv))
    (cons (los->s kanji)
          (los->s reading)))
  (define clip-verse prep-verse)

  (define parse-verse (compose combine-verse simpl-verse))

  (define subtitle (parse-verse subtitle-raw))
  (define intro (parse-verse intro-raw))
  (define summary (parse-verse summary-raw))
  (define verses (map (compose combine-verse clip-verse simpl-verse prep-verse)
                      ((sxpath "//p") verses-xe)))

  (list* subtitle intro summary verses))

(define (u->eng u-base)
  (define u (format "~a?lang=eng" u-base))
  (define xe (call/input-url (string->url u) get-pure-port html->xexp))
  (define (get-div class)
    (first ((sxpath (format "//div[@class=~s]" class)) xe)))

  (define subtitle-raw (list-tail (get-div "subtitle") 2))
  (define intro-raw (list-tail (get-div "intro") 2))
  (define summary-raw (rest (first (list-tail (get-div "summary") 2))))
  (define verses-xe (list '*TOP* (get-div "verses")))

  (define (prep-verse v)
    (list-tail v 3))
  (define simpl-verse
    (match-lambda
     [(? string? s)
      (list s)]
     [`(span (@ (class "verse")) . ,inside)
      empty]
     [`(span (@ (class "small")) . ,inside)
      (append-map simpl-verse inside)]
     [`(a (@ (class "footnote") . ,more) . ,inside)
      (append-map simpl-verse inside)]
     [`(sup . ,inside)
      empty]))
  (define (parse-verse v)
    (append-map simpl-verse v))

  (define subtitle (los->s (parse-verse subtitle-raw)))
  (define intro (los->s (parse-verse intro-raw)))
  (define summary (los->s (parse-verse summary-raw)))
  (define verses (map (compose los->s parse-verse prep-verse)
                      ((sxpath "//p") verses-xe)))

  (list* subtitle intro summary verses))

(struct card (volume book chapter verse kanji reading meaning)
        #:transparent)

(define u "http://www.lds.org/scriptures/bofm/1-ne/1")
(define jpn (u->jpn u))
(define eng (u->eng u))
(unless (= (length jpn) (length eng))
        (error 'bom2se "Japanese and English are different lengths! ~a" u))

(define cards
  (for/list ([k*r (in-list jpn)]
             [m (in-list eng)]
             [verse (in-sequences (in-list (list "Subtitle" "Introduction" "Summary"))
                                  (in-naturals 1))])
            (match-define (cons k r) k*r)
            (card "bofm" "1-ne" "1" verse k r m)))

(pretty-print cards)

;; DONE Parse a Japanese page
;; DONE Parse an English page
;; TODO Parse a book TOC
;; TODO Parse a volume TOC
;; TODO Parse the list of volumes TOC