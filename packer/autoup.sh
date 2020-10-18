#!bin/bash
a=1
i=2
while :
do
  aws mediaconvert list-jobs --endpoint-url https://qqvfzmfac.mediaconvert.ap-northeast-2.amazonaws.com --status COMPLETE | awk '/aws-mediaconvert1-output/ {print "link: "$2}' |head -n 3 |grep MP4 |sed 's/\"//g' |sed 's/$/.mp4/g' > /home/ec2-user/compare/mp4-ori.txt
  #mediaconvert로 jobs를 불러오는데에 3초정도의 시간소요가 되는데 그 시간동안 mp4-ori.txt의 파일은 공백이된다. 
  #공백파일과 diff를 하게되면 exit 코드는 0이 되기때문에 if문이 실행이 안된다. 따라서 sleep으로 지연시간을 걸어준다.
  sleep 5
  diff /home/ec2-user/compare/mp4-ori.txt /home/ec2-user/compare/mp4-com.txt
    if [ $? -eq 1 ]
    then
      cp /home/ec2-user/compare/test.md /home/ec2-user/quickstart/content/mp4/test$i.md
      aws mediaconvert list-jobs --endpoint-url https://qqvfzmfac.mediaconvert.ap-northeast-2.amazonaws.com --status COMPLETE | awk '/aws-mediaconvert1-output/ {print "link: "$2}' |head -n 3 |grep Thumbnails |awk -F / '{print $9}' |sed 's/\"//g' |sed 's/\(.*\)/"\1"/g' |sed 's/^/title: /g' >> /home/ec2-user/quickstart/content/mp4/test$i.md
      aws mediaconvert list-jobs --endpoint-url https://qqvfzmfac.mediaconvert.ap-northeast-2.amazonaws.com --status COMPLETE | awk '/aws-mediaconvert1-output/ {print "link: "$2}' |head -n 3 |grep MP4 |sed 's/\"//g' |sed 's/$/.mp4/g' |grep MP4 >> /home/ec2-user/quickstart/content/mp4/test$i.md
      sed -i 's/s3:\/\/aws-mediaconvert1-output\/output\/\//http:\/\/aws-mediaconvert1-output.s3.amazonaws.com\/output\//g' /home/ec2-user/quickstart/content/mp4/test$i.md
      aws mediaconvert list-jobs --endpoint-url https://qqvfzmfac.mediaconvert.ap-northeast-2.amazonaws.com --status COMPLETE | awk '/aws-mediaconvert1-output/ {print "image: "$2}' |head -n 3 |grep Thumbnails |sed 's/\"//g' |sed 's/$/.0000000.jpg/g'  |grep Thumbnails >> /home/ec2-user/quickstart/content/mp4/test$i.md
      sed -i 's/s3:\/\/aws-mediaconvert1-output\/output\/\//http:\/\/aws-mediaconvert1-output.s3.amazonaws.com\/output\//g' /home/ec2-user/quickstart/content/mp4/test$i.md
      sed -i '3d' /home/ec2-user/quickstart/content/mp4/test$i.md &&sed -i '2d' /home/ec2-user/quickstart/content/mp4/test$i.md

      echo "---" | sudo tee -a /home/ec2-user/quickstart/content/mp4/test$i.md
      aws mediaconvert list-jobs --endpoint-url https://qqvfzmfac.mediaconvert.ap-northeast-2.amazonaws.com --status COMPLETE | awk '/aws-mediaconvert1-output/ {print "link: "$2}' |head -n 3 |grep MP4 |sed 's/\"//g' |sed 's/$/.mp4/g' > /home/ec2-user/compare/mp4-com.txt
      i=`expr $i + 1`
    fi
done