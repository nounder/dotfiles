function posix-source
	for i in (cat $argv | grep "^[^#]")
		set arr (echo $i |tr = \n)
  		set -gx $arr[1] $arr[2]
	end
end
