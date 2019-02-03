SELECT
  id,
  average
FROM postmanaverageall
WHERE average >= ALL (SELECT R.average
                      FROM postmanaverageall AS R) 