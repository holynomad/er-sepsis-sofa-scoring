CREATE OR REPLACE
function fn_chk_er_sepsis	(	in_Jobtype	in varchar2,	/* 작업구분 : 
                                                                            'ALL_TOKEN'	 - E/R Sepsis CPG 대상 상세조건 Token 확인 및 리턴
																			'qSOFA_ON' 	 - 응급간호정보조사지 저장시 qSOFA 활성화 적용대상 여부 확인
																			'EXM_RESULT' - SOFA Score 평가시 E/R 내원후 항목별 첫 검사결과 Token 리턴
															*/
								in_Patno 	in varchar2,	/* 환자번호 											*/
                   		   		in_Meddate 	in date,		/* 내원일자		(yyyymmdd)								*/
                   		   		in_Medtime	in date,		/* 내원시간		(yyyymmddhh24mi)						*/
                   		   		in_Option	in varchar2		/* 옵션 		(확장성 고려) 							*/                   		   		
                   		  	) 	return varchar2	
/*====================================================================================================================
      Program ID      :   func_chk_er_sepsis_features
      Program 명      :   E/R Sepsis CPG (응급 패혈증환자 표준진료지침) 대상 필수 번들처방 및 상세조건 check
      Program 개요    :   기존 EGDT 프로세스를 개선하고, ICU Sepsis 번들 프로세스와 유사하게 E/R CPG 정의함 

      					  
	  Return value	  :	  1st Token  - E/R Sepsis CPG 적용대상여부 	(s_ER_Target_Yn)
	  					  2nd Token  - qSOFA #1 - 의식상태 건수 (Alert : 0, 그 외 : 1)(i_Conscious_Cnt)	  					  
	  					  3rd Token  - qSOFA #2 - SBP <= 100 건수 (i_SBP_Below100_Cnt)
	  					  4th Token  - qSOFA #3 - RR  >= 20  건수 (i_RR_Above22_Cnt)
	  					  5th Token  - qSOFA 활성화(+) 적용(충족)여부 (s_qSOFA_Yn)	  					  
	  					  6th Token  - qSOFA 활성화(+) 적용시간 (응급정보조사지.SOFATIME, d_SOFA_Time)	  					  
	  					  7th Token  - Infection 등록 유무 (s_Infection_Yn)
	  					  8th Token  - SOFA Score 2점 이상 여부 (s_SOFA_Score_Above2)
	  					  9th Token  - SOFA Score 저장상태(저장완료 vs. 임시저장) 여부 (s_SOFA_Score_State)	  					  
	  					  10th Token - Sepsis 번들처방 대상 목록 String	  					  
	  					  11th Token - PaO2 (ABGA) 내원후 첫 검사결과
	  					  12th Token - Creatinine (Cr) 내원후 첫 검사결과
	  					  13th Token - Platelet (PLT) 내원후 첫 검사결과
	  					  14th Token - Bilirubin, Total (T.bil) 내원후 첫 검사결과	  					  
	  					  15th Token - Blood Cx 시행이력
	  					  16th Token - Urine Cx 시행이력
	  					  17th Token - Sputum Cx 시행이력
	  					  18th Token - Lactate f/u 횟수 
	  					  19th Token - 최초 항생제 투여시간 - E/R 내원일시 (예: 1, 2, ...)
	  					  20th Token - 응급환자정보조사지 퇴실결과
	  					  21th Token - 퇴원요약지(EMR) 퇴원시 상태
	  					  22th Token - Sepsis 환자 등록/해지 이력(Y: 등록, N: 해지, null: 미등록)
	  					  23th Token - SOFA Score 평가일시 (yyyy-mm-dd hh24:mi) 
	  					  24th Token - Seps. 상병(A41.9) 등록유무
	  					  25th Token - MAP 계산결과
	  					  26th Token - Lactate 1st 실시시간
	  					  27th Token - Lactate 2nd 실시시간	  					  
	  					  28th Token - NEDIS 퇴원시 상태 (MDT005F1 > md_nedis_l1 > 치료결과(의정) 참조)
	  					  29th Token - CPG 2단계(SOFA Score) 평가 최종 등록자(이름)
	  					  30th Token - Sepsis 번들처방 기 처방이력 유무 (Y/N)                       
	  					  31th Token - CPG 1단계(Infection) 평가 최종 등록자(이름)	  					  
	  					  	  					         					  
  --------------------------------------------------------------------------------------------------------------------
      Modification Log
      =====================================================================================
      #   Date            Author                      							EditLabel
      -------------------------------------------------------------------------------------
          Description
      =====================================================================================
      1.  2017-07-12      Lee, Se-Ha				  							C170712-1      
          Create                       
	                            
	  2.  2017-08-24	  Lee, Se-Ha											M170824-1
	  	  Modify		  25th ~ 28th Token 항목 추가 (MAP, Lactate 1st/2nd 시간, NEDIS 퇴원시상태 등)
	  	  
	  3.  2017-09-15	  Lee, Se-Ha											M170915-1
	  	  Modify		  29th Token 항목 추가 (최종 SOFA Score 평가등록자)                              	  	                                
	  	  
	  4.  2017-09-25	  Lee, Se-Ha											M170925-1
	  	  Modify		  qSOFA (+) 조건 변경 (응급간호정보조사지 上 "진료결과 = 입원" 제거)
	  	  
	  5.  2017-09-26	  Lee, Se-Ha											M170926-1
	  	  Modify		  E/R 내원후 첫 검사결과 내용중 부등호(<, >) 특수문자 replace 적용
	  	  
	  6.  2017-09-26	  Lee, Se-Ha											M170926-2
	  	  Modify		  검사결과 조회시 Text 포함 결과 filtering (fn_isnum) 적용
	  	  
	  7.  2017-10-19	  Lee, Se-Ha											M171019-1
	  	  Modify		  30th Token 항목 추가 (Sepsis 번들처방 기 처방이력 유무 (Y/N))
	  	  
	  8.  2017-10-23	  Lee, Se-Ha											
	  	  Modify		  CPG 2단계 최종평가 여부 필수조건 추가 				M171023-1
	  	  Modify		  31th Token 항목 추가 (CPG 1단계 최종평가자)			M171023-2	  	  
	                                                                                     
	  9.  2017-11-24	  Lee, Se-Ha											M171124-1
	  	  Modify		  응급정보조사지 저장시점 qSOFA 판단조건(의식/SBP/RR) 
	  	  				  미입력된 경우 nvl 적용
	  	  				  
	  10. 2017-11-27	  Lee, Se-Ha											M171127-1
	  	  Modify		  응급정보조사지 저장시 qSOFA 판단조건 중 SBP 미입력된 경우 
	  	  				  충족조건( <= 100) nvl 적용 
	  	  				  
	  11. 2017-11-30	  Lee, Se-Ha											M171130-1
	  	  Modify		  응급정보조사지 저장시 UMLS 주증상에 CPR 등록된 환자는
	  	  				  qSOFA 활성화 대상에서 제외 
	  	  				  
	  12. 2018-02-01	  Lee, Se-Ha											M180201-1
	  	  Modify		  응급정보조사지 의식상태(CONSSTAT) 체크 조건 개선(Alert 제외한 모두 1 적용) 
	  	  
	  13. 2018-02-14	  Lee, Se-Ha											M180214-1
	  	  Modify		  응급정보조사지 UMLS 주증상 DOA는 qSOFA 활성화 대상 제외 
	  	  	          
 =====================================================================================================================*/                        	                     		 
is    
	s_Locate				varchar2(2)		:= fn_getlocate;									/* 병원 구분		 */
    s_Rtn_Token				varchar2(500)	:= null;     										/* 최종 Return Token */
          
    s_System_Open_Yn		varchar2(1)		:= 'N';												/* E/R Sepsis 병원별 적용 D/B 권한								*/          
    s_ER_Target_Yn			varchar2(1)		:= 'N';												/* E/R Sepsis CPG 적용대상여부 (default : N)				 	*/             
    
    i_Conscious_Cnt			number(1)		:= 0;	                 							/* qSOFA #1 - 의식상태 건수 (Alert : 0, 그 외 : 1) 				*/
    i_SBP_Below100_Cnt		number(1)		:= 0;												/* qSOFA #2 - SBP <= 100 건수									*/
    i_RR_Above22_Cnt		number(1)		:= 0;												/* qSOFA #3 - RR  >= 20  건수									*/    
    s_qSOFA_Yn				varchar2(1)		:= 'N';												/* qSOFA 활성화(+) 대상(충족) 여부								*/    
                                                                                                                       
    d_SOFA_Time				date			:= to_date(null);									/* qSOFA 활성화 시간(응급정보조사지.SOFATIME)							*/
    
    s_Infection_Yn			varchar2(1)		:= null;											/* Infection 여부 (No Infection : N, 그 외 : Y)					*/
    s_SOFA_Score_Above2		varchar2(1)		:= null;											/* SOFA Score 합계 2점이상 유무 (Y/N)							*/
    s_SOFA_Score_Exists		varchar2(1)		:= null;											/* SOFA Score 이력 존재여부 (Y/N)								*/
    s_SOFA_Score_State		varchar2(1)		:= null;											/* SOFA Score 저장상태(저장완료 (C) vs. 임시저장 (T))			*/

    s_Exm_Blood				varchar2(2)		:= 'XX';											/* Culture & Blood 실시이력 (검사 2)							*/    
    s_Exm_Urine				varchar2(2)		:= 'XX';											/* Culture(비뇨기검체) 실시이력 (검사 2)						*/                
    s_Exm_Sputum			varchar2(2)		:= 'XX';											/* Culture(호흡기검체) 실시이력 (검사 2)						*/                
    s_Exm_Token				varchar2(40)	:= 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';		/* E/R Sepsis 번들처방(검사) 유무 Token (오픈시점 40자리 : 진료공통코드.COMCD1 = 754, COMCD2 = ERSEPS% 참조) */
                
	s_PaO2_Result			varchar2(10)	:= null;				  					  		/* PaO2 (ABGA) 내원후 첫 검사결과								*/
	s_Cr_Result				varchar2(10)	:= null;				  					  		/* Creatinine (Cr) 내원후 첫 검사결과							*/
	s_PLT_Result			varchar2(10)	:= null;				  					  		/* Platelet (PLT) 내원후 첫 검사결과							*/
	s_TBil_Result			varchar2(10)	:= null;				  					  		/* Bilirubin, Total (T.bil) 내원후 첫 검사결과    				*/

	d_FstAnti_Acttime       date			:= to_date(null);									/* 최초 항생제 투여시간											*/
	
	i_Lactate_Cnt			number(1)		:= 0;												/* E/R 내원후 Lactate f/u 횟수									*/
	i_FstAnti_Diff_Medtime	number(10)		:= 999;												/* 최초 항생제 투여시간 - E/R 내원일시 gap (예: 1, 2.23, ...)	*/

	
	s_ER_Dsch_Rslt			varchar2(10)	:= null;											/* 응급환자정보조사지 퇴실결과 									*/
	
	s_Sepsis_Yn				varchar2(1)		:= null;											/* Sepsis 이력(EGDT환자관리.RGTYN) 유무 (Y: 등록, N: 해지, 그외:null) */
	
	s_Score_EvalTime		varchar2(20)	:= null;											/* SOFA Score 평가일시 											*/
	s_Seps_Diag_Yn			varchar2(10)	:= null;											/* Sepsis 상병(A41.7) 등록유무 									*/
	
	s_Error_Yn				varchar2(1)		:= 'N';												/* 체크 단계별 오류 로깅용 변수 #1								*/
	s_Error_Msg				varchar2(500)	:= null;											/* 체크 단계별 오류 로깅용(상세내용) 변수 #2					*/	
		
	i_MAP_Result			number(6)		:= 999;												/* [M170824-1] E/R 내원후 첫(최초) 측정 MAP 계산결과			*/							
	d_Lactic_1st_Time		date			:= to_date(null);									/* [M170824-1] E/R 내원후 최초(1st) Lactate 실시시간			*/
	d_Lactic_2nd_Time		date			:= to_date(null);									/* [M170824-1] E/R 내원후 2nd Lactate 실시시간					*/
	s_Dsch_State			varchar2(20)	:= null;											/* [M170824-1] NEDIS 퇴원시 상태 (치료결과(의정) 참조)	*/																
	i_Sbp_Erinf				number(6)		:= 999;												/* [M170824-1] 응급정보조사지(BLDPRESS) SBP 측정치		*/
	i_Dbp_Erinf				number(6)		:= 999;												/* [M170824-1] 응급정보조사지(BLDPRESS) DBP 측정치		*/
	
	s_Score_RgtNm			varchar2(10)	:= null;											/* [M170915-1] CPG 2단계 SOFA Score 평가 최종 등록자(이름)		*/	
	s_Bundle_Yn				varchar2(1)		:= 'N';												/* [M171019-1] Sepsis 번들처방 기 처방이력 유무 (Y/N)			*/  
	s_Infection_RgtNm		varchar2(10)	:= null;											/* [M171023-2] CPG 1단계 Infection 평가 최종 등록자(이름)		*/		
    
begin   
	/*----------------------------------------------------------------------------------*/	    		  
    /* #1-1. E/R Sepsis CPG 병원별 적용 D/B 권한 Check									*/
  	/*----------------------------------------------------------------------------------*/
  	begin
		select
				decode(count(a.COMCDNM3), 0, 'N', 'Y')	/* D/B 권한 오픈시 DELDATE 풀어줄 것! */									
		  into
		  		s_System_Open_Yn
      	  from
               	진료공통코드	a
         where
               	a.COMCD1   	= 'DEPT'     				/* 공통코드1 */
           and 	a.COMCD2   	= 'MDP130_SEPSIS'			/* 공통코드2 */	
           and	a.COMCD3	= 'ALL'						/* 공통코드3 : ALL - 해당병원 전체 */	
           and 	a.DELDATE is null;
	
  	exception
  	
  		when no_data_found then

			s_System_Open_Yn  := 'N';							
	   	
		when others then	     
		
			s_System_Open_Yn  := 'X';					/* Set error flag : X */
  	
  	end;	          
  	
   
	/*----------------------------------------------------------------------------------*/	    		  
  	/* #1-2. 권한 유효하면 계속해서 E/R Sepsis CPG 상세조건 Check 시작					*/
  	/*----------------------------------------------------------------------------------*/
  	if	s_System_Open_Yn = 'Y'	then	                                                  
  	
  	    
  	    /*------------------------------------------------------------------------------*/	    		  
	  	/* #2-1. E/R Sepsis CPG 적용대상 여부 확인	 									*/
	  	/*------------------------------------------------------------------------------*/		
		begin
	  	    select
			     	decode(count(a.PATNO), 0, 'N', 'Y')
			  into
			  		s_ER_Target_Yn
			  from
			       	응급정보조사지	a,
			       	환자마스터	b
			 where
			       	a.PATNO   	= in_Patno
			   and 	a.MEDDATE 	= in_Meddate
			   and 	a.MEDTIME 	= in_Medtime
			   /* and 	nvl(a.ERRSLT, '*') = '1' */						/* 응급간호정보조사지 - 응급센터 퇴실결과 : 입원 --> [M170925-1] 상기 조건 제거 */
			   and 	a.INRSN1 	= '1'                   				/* 응급간호정보조사지 - 질병구분 : 질병				*/
			   and 	b.PATNO 	= a.PATNO
			   and 	floor((a.MEDDATE - b.BIRTDATE) / 365) >= 15; 		/* 만 15세 이상										*/
        
		exception
	  	
	  		when no_data_found then
	
				s_ER_Target_Yn  := 'N';							
		   	
			when others then	     
			
				s_ER_Target_Yn 	:= 'X';														
				s_Error_Yn	 	:= 'Y';														
				s_Error_Msg	 	:= '#2-1. E/R CPG 대상여부 failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
	  	
	  	end; 
	  	
	  	
		/*------------------------------------------------------------------------------------------*/	    		  
	  	/* #2-2. qSOFA 활성화 적용시간 체크 (SOFATIME)										*/		  	
	  	/* 		- [M171023-3] 최초 SOFA 활성화 이후 [질병구분]이 질병에서 질병외 로 변경된 경우도	*/
	  	/*		  최종 Sepsis 평가이력 조회시 모니터링 하기 위해 #5에서 #2-2로 체크 복사	*/
	  	/*------------------------------------------------------------------------------------------*/			  		  				  	
	  	begin 
			select
			       	a.SOFATIME
			  into
			  		d_SOFA_Time
			  from
			       	응급정보조사지	a
			 where
			       	a.PATNO   	= in_Patno
			   and 	a.MEDDATE 	= in_Meddate
			   and 	a.MEDTIME 	= in_Medtime;
			       
		exception
		
			when no_data_found then

				d_SOFA_Time		  	:= to_date(null);							
		   	
			when others then	     
			
				d_SOFA_Time		  	:= to_date(null);							
				s_Error_Yn	 		:= 'Y';														
				s_Error_Msg	 		:= '#2-2. SOFATIME failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
						
		end;        			  	
	  	
	  	
	  	/*--------------------------------------------------------------------------------------*/	    		  
	  	/* #3. E/R Sepsis CPG 적용대상만 qSOFA > Infection > 번들처방 > SOFA Score Check 시작 	*/
	  	/* 		- [M171023-3] qSOFA 활성화 이후 CPG 적용대상 기준 변경된 case도 CPG 이력조회 	*/
	  	/*--------------------------------------------------------------------------------------*/		
	  	if	(s_ER_Target_Yn		=	'Y')	or
	  		(d_SOFA_Time	is not null)	then
	  	    
	  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #4-1. qSOFA 활성화 조건 #1 : 의식상태 (Alert 외 나머지 해당시 Y, 응급간호정보조사지)	*/
		  	/*--------------------------------------------------------------------------------------*/			  	
		  	begin
				select
				       	nvl(count(a.CONSSTAT), 0)
				  into
				  		i_Conscious_Cnt
				  from
				       	응급정보조사지	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.MEDDATE 	= in_Meddate
				   and 	a.MEDTIME 	= in_Medtime
				   and  nvl(a.CONSSTAT, 'A')	<> 'A'	/* in ('V', 'P', 'D') */			/* 의식상태 alert 제외 --> [M180201-1] Alert를 제외한 모든 의식상태 체크(UnResponsive 포함) */				         	
				       																		/* [M171124-1] 응급정보조사지 저장시점에 의식상태 미입력 할 수 있기 때문에 nvl 처리 */
				   and	not exists  (  	/* [M171130-1] UMLS 주증상에 CPR 및 DOA 등록된 환자는 qSOFA 활성화 충족 조건에서 제외 */
				   						select
				   								'CPR'
				   						  from
				   						  		주호소마스터	x
				   						 where
				   						 		x.PATNO		= a.PATNO
				   						   and	x.MEDDATE	= a.MEDDATE
				   						   and	x.MEDTIME	= a.MEDTIME
				   						   and	(
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0007203') or	/* UMLS 주증상1 CPR 등록 */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0007203') or    /* UMLS 주증상2 CPR 등록 */
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0007203') or	/* UMLS 주증상3 CPR 등록 */
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0421619') or	/* [M180214-1] UMLS 주증상1 DOA 등록 */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0421619') or	/* [M180214-1] UMLS 주증상2 DOA 등록 */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0421619') 		/* [M180214-1] UMLS 주증상3 DOA 등록 */ 				   						   							   						   								   						   							   						   			 				   						   							   						   				
				   						   		)
				   					);
				   					
				       
			exception
			
				when no_data_found then
	
					i_Conscious_Cnt := 0;							
			   	
				when others then	     
				
					i_Conscious_Cnt := 0;
					s_Error_Yn	 	:= 'Y';														
					s_Error_Msg	 	:= '#4-1. 의식상태 failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
					
			end;
            
			
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #4-2. qSOFA 활성화 조건 #2 : SBP <= 100 (응급간호정보조사지)						 	*/
		  	/*--------------------------------------------------------------------------------------*/			  		  		
		  	begin   
				select
				       	nvl(count(a.PATNO), 0)
				  into
				  		i_SBP_Below100_Cnt
				  from
				       	응급정보조사지	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.MEDDATE 	= in_Meddate
				   and 	a.MEDTIME 	= in_Medtime
				   and 	nvl(regexp_substr(a.BLDPRESS, '[^/]+', 1, 1), 10) <= 100		/* SBP <= 100 */
				   																		/* [M171124-1] 응급정보조사지 저장시점에 BP 미입력 할 수 있기 때문에 nvl 처리 */
				   																		/* [M171127-1] 응급정보조사지 저장시점에 BP 미입력시 활성화 충족(<= 100) nvl 처리 */
				   and	not exists  (  	/* [M171130-1] UMLS 주증상에 CPR 및 DOA 등록된 환자는 qSOFA 활성화 충족 조건에서 제외 */
				   						select
				   								'CPR'
				   						  from
				   						  		주호소마스터	x
				   						 where
				   						 		x.PATNO		= a.PATNO
				   						   and	x.MEDDATE	= a.MEDDATE
				   						   and	x.MEDTIME	= a.MEDTIME
				   						   and	(
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0007203') or	/* UMLS 주증상1 CPR 등록 */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0007203') or    /* UMLS 주증상2 CPR 등록 */
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0007203') or	/* UMLS 주증상3 CPR 등록 */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0421619') or	/* [M180214-1] UMLS 주증상1 DOA 등록 */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0421619') or	/* [M180214-1] UMLS 주증상2 DOA 등록 */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0421619') 		/* [M180214-1] UMLS 주증상3 DOA 등록 */				   						   			
				   						   		)
				   					);				   																		
				       
			exception
			
				when no_data_found then
	
					i_SBP_Below100_Cnt 	:= 0;							
			   	
				when others then	     
				
					i_SBP_Below100_Cnt 	:= 0;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#4-2. SBP <= 100 failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		

			end;
					  	
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #4-3. qSOFA 활성화 조건 #3 : RR >= 20 (응급간호정보조사지)						 	*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	nvl(count(a.RESPCNT), 0)
				  into
				  		i_RR_Above22_Cnt
				  from
				       	응급정보조사지	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.MEDDATE 	= in_Meddate
				   and 	a.MEDTIME 	= in_Medtime
				   and 	nvl(a.RESPCNT, 0) 	>= 22                                 	/* 호흡수 >= 22 */
																				   	/* [M171124-1] 응급정보조사지 저장시점에 RR 미입력 할 수 있기 때문에 nvl 처리 */
				   and	not exists  (  	/* [M171130-1] UMLS 주증상에 CPR 및 DOA 등록된 환자는 qSOFA 활성화 충족 조건에서 제외 */
				   						select
				   								'CPR'
				   						  from
				   						  		응급정보조사지	x
				   						 where
				   						 		x.PATNO		= a.PATNO
				   						   and	x.MEDDATE	= a.MEDDATE
				   						   and	x.MEDTIME	= a.MEDTIME
				   						   and	(
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0007203') or	/* UMLS 주증상1 CPR 등록 */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0007203') or    /* UMLS 주증상2 CPR 등록 */
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0007203') or	/* UMLS 주증상3 CPR 등록 */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0421619') or	/* [M180214-1] UMLS 주증상1 DOA 등록 */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0421619') or	/* [M180214-1] UMLS 주증상2 DOA 등록 */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0421619') 		/* [M180214-1] UMLS 주증상3 DOA 등록 */				   						   			
				   						   		)
				   					);				   								 
				   																		
				       
			exception
			
				when no_data_found then
	
					i_RR_Above22_Cnt  	:= 0;							
			   	
				when others then	     
				
					i_RR_Above22_Cnt	:= 0;														
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#4-3. RR >= 22 failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
								
			end;
                     
			
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #4-4. qSOFA 활성화 여부 판단 : 위 3가지 항목중 2가지 이상 해당되면, CPG 대상(+)	 	*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  			  	
		  	if	i_Conscious_Cnt + i_SBP_Below100_Cnt + i_RR_Above22_Cnt >= 	2	then

		  		s_qSOFA_Yn		:= 'Y';		  		
		  	       
		  	else
		  		
		  		s_qSOFA_Yn		:= 'N';
		  	
		  	end if;       
		  	
		       
			/*------------------------------------------------------------------------------------------*/	    		  
		  	/* #5. qSOFA 활성화 적용시간 체크 (응급정보조사지.SOFATIME)										*/		  	
		  	/* 		- [M171023-3] 최초 SOFA 활성화 이후 [질병구분]이 질병에서 질병외 로 변경된 경우도	*/
		  	/*		  최종 Sepsis 평가이력 조회시 모니터링 하기 위해 #2-2로 로직 복사			*/
		  	/*		- 기존 로직흐름 히스토리 유지 위해 중복 로직(#2-2 및 %5) 그냥 유지 -_-;				*/  
		  	/*------------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	a.SOFATIME
				  into
				  		d_SOFA_Time
				  from
				       	응급정보조사지	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.MEDDATE 	= in_Meddate
				   and 	a.MEDTIME 	= in_Medtime;
				       
			exception
			
				when no_data_found then
	
					d_SOFA_Time		  	:= to_date(null);							
			   	
				when others then	     
				
					d_SOFA_Time		  	:= to_date(null);							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#5. 응급정보조사지.SOFATIME failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
							
			end;        		
		

			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #6. Infection 등록 여부 (Y/N)														*/		  	
		  	/*--------------------------------------------------------------------------------------*/			  				        		  	
		  	begin 
				select
				       	max(case when a.ITEMVAL = 'Y' then 'N' else 'Y' end)		/* No Infection (EF99)인 경우 N, 나머지 존재하면 Y */
				  into
				  		s_Infection_Yn
				  from
				       	설문항목구성마스터	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSIF'
				   and	a.SETCODE	= 'EF99'
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_Infection_Yn		:= null;							
			   	
				when others then	     
				
					s_Infection_Yn	  	:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#6. Infection (설문항목구성마스터) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
								
			end;  
		  	   
		  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #7-1. SOFA Score 평가점수 2점이상 여부 (Y/N)											*/		  	
		  	/*--------------------------------------------------------------------------------------*/			
            begin 
				select
				       	decode(max(a.ITEMVAL), 'Yes', 'Y', 'No', 'N', null)					
				  into
				  		s_SOFA_Score_Above2
				  from
				       	설문항목구성마스터	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSSC'
				   and	a.SETCODE	= 'EC08'			/* SOFA Score 합계 2점이상 유무 */
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_SOFA_Score_Above2		:= null;							
			   	
				when others then	     
				
					s_SOFA_Score_Above2	  	:= null;							
					s_Error_Yn	 			:= 'Y';														
					s_Error_Msg	 			:= '#7-1. SOFA Score 합계 2점이상유무 (설문항목구성마스터) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
								
			end;  
			

			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #7-2-1. SOFA Score 평가 존재여부 (Y/N)												*/
		  	/*--------------------------------------------------------------------------------------*/					  	
			begin 
				select
				       	decode(count(a.PATNO), 0, 'N', 'Y')
				  into
				  		s_SOFA_Score_Exists
				  from
				       	설문항목구성마스터	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSSC'
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_SOFA_Score_Exists		:= null;							
			   	
				when others then	     
				
					s_SOFA_Score_Exists	  	:= null;							
					s_Error_Yn	 			:= 'Y';														
					s_Error_Msg	 			:= '#7-2-1. SOFA Score 평가이력(설문항목구성마스터) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
													
			end;  		
			
			  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #7-2-2. SOFA Score 평가 저장상태 판정												*/
		  	/*--------------------------------------------------------------------------------------*/					  	
			if	s_SOFA_Score_Exists	= 	'Y'	then
			       
				/* SOFA Score 이력있으나, [합계 2점이상 여부] 항목 미체크 된 경우 : 임시저장(T) */
				if	Trim(s_SOFA_Score_Above2)	is null		then
				       
					s_SOFA_Score_State	:= 'T';
				
				/* SOFA Score 이력있고, [합계 2점이상 여부] 항목 체크 된 경우 : 저장완료(C) */				
				else

					s_SOFA_Score_State	:= 'C';				
				
				end if;			

			/* SOFA Score 이력없는 경우 : 미등록 (X) */							
			else                                            
			
				s_SOFA_Score_State	:= 'X';										
			
			end if;
			         
						  	
			  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #8. Sepsis Bundle 처방 Token 생성 													*/		  	
		  	/* ★ ICU Sepsis와 다르게 그냥 default로 기본 번들목록 (D/B) 넣어주고,                  */
		  	/*    의사들이 알아서 수정하도록 하자....(도저히 다른 S/R까지 커버할 수 없네..) ★ 		*/		  			  	
		  	/*--------------------------------------------------------------------------------------*/
		  	
		  	

			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #9-1. E/R 내원후 첫 ABGA (PaO2) 검사결과 연동										*/		  			  			  	
		  	/*--------------------------------------------------------------------------------------*/		  	
		  	begin
	            select
						/* [M170926-1] 검사결과에 부등호(<, >) 입력된 경우 발견되어 replace 적용 */                                                                        
						/* [M170926-2] 검사결과에 Text 입력된 녀석들이 많아서...부등호 걸러내고, fn_isnum으로 문자포함여부 filtering */
						decode(fn_isnum(max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', '')))), 0, '', max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', ''))))
				  into
				  		s_PaO2_Result
				  from
				  		검사처방이력	a
				  	 ,	검사결과이력	b
				 where  				 		
				 		a.PATNO		= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime
				   and	a.DISCYN	is null
				   and	a.ORDCD		= 'BM38150'
				   and	a.EXECDATE	= (
				   							select	/* 최초 시행 */
				   									min(x.EXECDATE)
				   							  from
				   							  		검사처방이력	x
				   						 	where
				   						 			x.PATNO 	= a.PATNO
				   						      and	x.MEDDATE 	= a.MEDDATE
				   						      and	x.MEDTIME 	= a.MEDTIME
   						      				  and	x.ORDCD		= 'BM38150'
				   						      and	x.DISCYN	is null
				   						      and	x.EXECDATE	is not null
				   						)
				   and	b.PATNO		= a.PATNO
				   and	b.ORDDATE	= a.ORDDATE
				   and	b.ORDSEQNO	= a.ORDSEQNO
				   and	b.EXAMCODE	= 'BM38150C'
				   and	b.RSLT1		is not null;
				         
			exception
			
				when no_data_found then
	
					s_PaO2_Result		:= null;							
			   	
				when others then	     
				
					s_PaO2_Result	  	:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#9-1. ABGA (PaO2, 검사결과이력.RSLT1) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
			end;  	
								   
		  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #9-2. E/R 내원후 첫 Creatinine (Cr) 검사결과	연동									*/
		  	/*--------------------------------------------------------------------------------------*/		  			  	
		  	begin
	            select
						/* [M170926-1] 검사결과에 부등호(<, >) 입력된 경우 발견되어 replace 적용 */                                                                        
						/* [M170926-2] 검사결과에 Text 입력된 녀석들이 많아서...부등호 걸러내고, fn_isnum으로 문자포함여부 filtering */
						decode(fn_isnum(max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', '')))), 0, '', max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', ''))))
				  into
				  		s_Cr_Result
				  from
				  		검사처방이력	a
				  	 ,	검사결과이력	b
				 where  				 		
				 		a.PATNO		= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime
				   and	a.DISCYN	is null
				   and	a.ORDCD		= 'BM37500'
				   and	a.EXECDATE	= (
				   							select	/* 최초 시행 */
				   									min(x.EXECDATE)
				   							  from
				   							  		검사처방이력	x
				   						 	where
				   						 			x.PATNO 	= a.PATNO
				   						      and	x.MEDDATE 	= a.MEDDATE
				   						      and	x.MEDTIME 	= a.MEDTIME
				   						      and	x.ORDCD		= 'BM37500'
				   						      and	x.DISCYN	is null
				   						      and	x.EXECDATE	is not null
				   						)
				   and	b.PATNO		= a.PATNO
				   and	b.ORDDATE	= a.ORDDATE
				   and	b.ORDSEQNO	= a.ORDSEQNO
				   and	b.EXAMCODE	= a.ORDCD
				   and	b.RSLT1		is not null;
				         
			exception
			
				when no_data_found then
	
					s_Cr_Result			:= null;							
			   	
				when others then	     
				
					s_Cr_Result	  		:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#9-2. Creatinine (Cr, 검사결과이력.RSLT1) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
			end; 
			 	
		  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #9-3. E/R 내원후 첫 Platelet (PLT) 검사결과	연동									*/
		  	/*--------------------------------------------------------------------------------------*/		  			  			  	
		  	begin
	            select                                                                                                                                                     
						/* [M170926-1] 검사결과에 부등호(<, >) 입력된 경우 발견되어 replace 적용 */                                                                        
						/* [M170926-2] 검사결과에 Text 입력된 녀석들이 많아서...부등호 걸러내고, fn_isnum으로 문자포함여부 filtering */
						decode(fn_isnum(max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', '')))), 0, '', max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', ''))))
				  into
				  		s_PLT_Result
				  from
				  		검사처방이력	a
				  	 ,	검사결과이력	b
				 where  				 		
				 		a.PATNO		= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime
				   and	a.DISCYN	is null
				   and	a.ORDCD		= 'GEML106'
				   and	a.EXECDATE	= (
				   							select	/* 최초 시행 */
				   									min(x.EXECDATE)
				   							  from
				   							  		검사처방이력	x
				   						 	where
				   						 			x.PATNO 	= a.PATNO
				   						      and	x.MEDDATE 	= a.MEDDATE
				   						      and	x.MEDTIME 	= a.MEDTIME
				   						      and	x.ORDCD		= 'GEML106'
				   						      and	x.DISCYN	is null
				   						      and	x.EXECDATE	is not null
				   						)
				   and	b.PATNO		= a.PATNO
				   and	b.ORDDATE	= a.ORDDATE
				   and	b.ORDSEQNO	= a.ORDSEQNO
				   and	b.EXAMCODE	= 'BD10600'
				   and	b.RSLT1		is not null;
				         
			exception
			
				when no_data_found then
	
					s_PLT_Result		:= null;							
			   	
				when others then	     
				
					s_PLT_Result		:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#9-3. Platelet (PLT, 검사결과이력.RSLT1) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
			end; 
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #9-4. E/R 내원후 첫 Bilirubin, Total (T.bil) 검사결과 연동							*/
		  	/*--------------------------------------------------------------------------------------*/		  					  	
		  	begin
	            select
						/* [M170926-1] 검사결과에 부등호(<, >) 입력된 경우 발견되어 replace 적용 */                                                                        
						/* [M170926-2] 검사결과에 Text 입력된 녀석들이 많아서...부등호 걸러내고, fn_isnum으로 문자포함여부 filtering */
						decode(fn_isnum(max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', '')))), 0, '', max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', ''))))
				  into
				  		s_TBil_Result
				  from
				  		검사처방이력	a
				  	 ,	검사결과이력	b
				 where  				 		
				 		a.PATNO		= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime
				   and	a.DISCYN	is null
				   and	a.ORDCD		= 'BM37200'
				   and	a.EXECDATE	= (
				   							select	/* 최초 시행 */
				   									min(x.EXECDATE)
				   							  from
				   							  		검사처방이력	x
				   						 	where
				   						 			x.PATNO 	= a.PATNO
				   						      and	x.MEDDATE 	= a.MEDDATE
				   						      and	x.MEDTIME 	= a.MEDTIME
				   						      and	x.ORDCD		= 'BM37200'
				   						      and	x.DISCYN	is null
				   						      and	x.EXECDATE	is not null
				   						)
				   and	b.PATNO		= a.PATNO
				   and	b.ORDDATE	= a.ORDDATE
				   and	b.ORDSEQNO	= a.ORDSEQNO
				   and	b.EXAMCODE	= a.ORDCD
				   and	b.RSLT1		is not null;
				         
			exception
			
				when no_data_found then
	
					s_TBil_Result		:= null;							
			   	
				when others then	     
				
					s_TBil_Result		:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#9-4. Bilirubin, Total (T.bil, 검사결과이력.RSLT1) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
			end; 
		  	
                  
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #10. Blood Cx, 호기/혐기 처방/실시 이력 Check										*/
		  	/*--------------------------------------------------------------------------------------*/		  			           
		  	begin
				select  /* E/R 내원이후 실시이력 있으면 Y, 미실시는 N, 미처방시 X */   
						nvl(max(decode(a.ORDCD,	'BN41440',	case when (a.EXECDATE is not null) then 'Y' else 'N' end)),   'X')	||	/* Culture & Sensitivity(blood),Aerobic  (호기)				*/
						nvl(max(decode(a.ORDCD,	'BN41490',	case when (a.EXECDATE is not null) then 'Y' else 'N' end)),   'X')		/* Culture & Sensitivity(blood),Anaerobic(혐기)				*/
				  into
				  		s_Exm_Blood
	              from    
	              		검사처방이력	a
	             where
	                    a.PATNO    	= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime                                                          
	               and	a.ORDCD		in 	(	               		
	               							'BN41440',				/* Culture & Sensitivity(blood),Aerobic	 (호기) 	*/
	               							'BN41490'				/* Culture & Sensitivity(blood),Anaerobic(혐기)		*/               							
	               						)
	               and  a.DISCYN 	is null;
	               
	     	exception                    
		     	when no_data_found then	     
	     	
		  			s_Exm_Blood 		:= 'XX';
		  	
		  		when others then	     
		  		
		  			s_Exm_Blood			:= 'XX';															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#10. Blood Cx (검사처방이력) 실시이력 failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;                                                                                                      
		  	
		  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #11. Urine Cx 처방/실시 이력 Check													*/
		  	/*--------------------------------------------------------------------------------------*/		  			           
		  	begin
				select  /* E/R 내원이후 실시이력 있으면 Y, 미실시는 N, 미처방시 X */   
						nvl(max(decode(a.ORDCD,	'BN4101Z',	case when (a.EXECDATE is not null) and (a.SPCCODE1 = 'C13') then 'Y' else 'N' end)), 'X')	||	/* Gram's stain [Urine] 			 		*/
						nvl(max(decode(a.ORDCD,	'BN41430Z',	case when (a.EXECDATE is not null) and (a.SPCCODE1 = 'C13') then 'Y' else 'N' end)), 'X')		/* Culture(비뇨기) & Antibiotic MIC			*/
				  into
				  		s_Exm_Urine
	              from    
	              		검사처방이력	a
	             where
	                    a.PATNO    	= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime                                                          
	               and	a.ORDCD		in 	(	               		
	               							'BN4101Z',				/* Gram's stain 							*/               							
	               							'BN41430Z'				/* Culture(비뇨기) & Antibiotic MIC			*/
	               						)
	               and  a.DISCYN 	is null;
	               
	     	exception                    
		     	when no_data_found then	     
	     	
		  			s_Exm_Urine 		:= 'XX';
		  	
		  		when others then	     
		  		
		  			s_Exm_Urine			:= 'XX';															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#11. Urine Cx (검사처방이력) 실시이력 failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;               		  	
		  	      
		  	      
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #12. Sputum Cx 처방/실시 이력 Check													*/
		  	/*--------------------------------------------------------------------------------------*/		  			           
		  	begin
				select  /* E/R 내원이후 실시이력 있으면 Y, 미실시는 N, 미처방시 X */   
						nvl(max(decode(a.ORDCD,	'BN4101Z',	case when (a.EXECDATE is not null) and (a.SPCCODE1 = 'A07') then 'Y' else 'N' end)), 'X')	||	/* Gram's stain [Sputum] 			 		*/
						nvl(max(decode(a.ORDCD,	'BN41410Z',	case when (a.EXECDATE is not null) and (a.SPCCODE1 = 'A07') then 'Y' else 'N' end)), 'X')		/* Culture(호흡기) & Antibiotic MIC			*/
				  into
				  		s_Exm_Sputum
	              from    
	              		검사처방이력	a
	             where
	                    a.PATNO    	= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime                                                          
	               and	a.ORDCD		in 	(	               		
	               							'BN4101Z',				/* Gram's stain 							*/               							
	               							'BN41410Z'				/* Culture(호흡기) & Antibiotic MIC			*/
	               						)
	               and  a.DISCYN 	is null;
	               
	     	exception                    
		     	when no_data_found then	     
	     	
		  			s_Exm_Sputum 		:= 'XX';
		  	
		  		when others then	     
		  		
		  			s_Exm_Sputum		:= 'XX';															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#12. Sputum Cx (검사처방이력) 실시이력 failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;  		  	                                                                                                            
		  
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #13. Lactate f/u 횟수 Check															*/
		  	/*--------------------------------------------------------------------------------------*/		  			           
		  	begin        
			  	select  /* E/R 내원이후 실시된 Lactate 검사 Count */   
						count(a.PATNO)
				  into
				  		i_Lactate_Cnt
	              from    
	              		검사처방이력	a
	             where
	                    a.PATNO    	= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime                                                          
	               and	a.ORDCD		= 'BM3850'						/* Lactic Acid (serum Lactate) 							*/	               														               						
	               and  a.DISCYN 	is null
	               and	a.EXECDATE	is not null;
		  	
		  	exception                    
		     	when no_data_found then	     
	     	
		  			i_Lactate_Cnt 		:= 0;
		  	
		  		when others then	     
		  		
		  			i_Lactate_Cnt		:= 0;															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#13. Lactate (검사처방이력) 실시이력 failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;  		  	 
		  			  	  				  	
		
		    /*--------------------------------------------------------------------------------------*/	    		  
		  	/* #14-1. 최초 항생제 투여시간 Check													*/
		  	/*--------------------------------------------------------------------------------------*/		  			
		  	begin
				select	
				       	min(to_date(to_char(c.ACTDATE, 'yyyymmdd') || nvl(replace(c.ACTTIME2, ':', ''), replace(c.ACTTIME, ':', '')), 'yyyymmddhh24mi'))
				  into
				  		d_FstAnti_Acttime
				  from
				       	투약이력 	a
				  	 ,	처방코드마스터 	b
				     ,	간호Acting 	c				   
				 where
				       	a.PATNO   		= in_Patno
				   and	a.MEDDATE		= in_Meddate
				   and	a.MEDTIME		= in_Medtime
				   and	a.PATSECT		= 'E'
				   and 	a.DISCYN		is null
				   and 	b.ORDCD    		= a.ORDCD								   
				   and 	b.ORDGRP   		like 'B%'
				   and 	b.DRUGKIND 		in	(
												'4',					/* 경험적 항생제 						*/
		           								'5'						/* 제한 항생제(진료지원공통코드.LARGCD = SD01) 	*/				   			
			         						)
				   and 	c.PATNO			= a.PATNO
				   and 	c.ORDDATE		= a.ORDDATE
				   and 	c.ORDSEQNO		= a.ORDSEQNO
				   and 	c.ACTTYPE		in (    /* 아래 ACTTYPE E/R 수간호사 컨펌 */
				   								'Y',
				   								'X'
				   							)
				order by
						to_date(to_char(c.ACTDATE, 'yyyymmdd') || nvl(replace(c.ACTTIME2, ':', ''), replace(c.ACTTIME, ':', '')), 'yyyymmddhh24mi');
				
		  	exception                    
		     	when no_data_found then	     
	     	
		  			d_FstAnti_Acttime	:= to_date(null);
		  	
		  		when others then	     
		  		
		  			d_FstAnti_Acttime	:= to_date(null);															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#14. 최초 항생제 투여시간(간호Acting) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;    		  	 
		  	
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #14-2. 최초 항생제 투여시간 - 내원일시(in_Medtim) gap								*/
		  	/*--------------------------------------------------------------------------------------*/		  			
		  	if	Trim(d_FstAnti_Acttime) is not null	then
		  	                                                                               
		  		/* 분(min)을 시간(hour)단위로 환산하여 소수점 둘째 자리까 반올림 적용, 표기 (예: 10.08시간) */
		  		/* [M170824-1] 시간(hour)에서 분(min)단위로 표기 변경 요청  */
		  		/* i_FstAnti_Diff_Medtime := round((d_FstAnti_Acttime - in_Medtime), 2) * 24; */
		  		i_FstAnti_Diff_Medtime := round(d_FstAnti_Acttime - in_Medtime, 2) * 24 * 60;
		  		
		  	else
		  		
		  		i_FstAnti_Diff_Medtime := 999;		  		
		  	
		  	end if;
		  	
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #15. 응급환자 정보조사지 上 퇴실결과 Check											*/
		  	/*--------------------------------------------------------------------------------------*/		  			
		  	begin
				select				      
					 	e.COMCDNM3		/* 응급실 퇴실결과 */
				  into
				  		s_ER_Dsch_Rslt
				  from 					       
				     	응급정보조사지 		d
				     ,	진료공통코드 		e
				 where
				       	d.PATNO   		= in_Patno
				   and	d.MEDDATE		= in_Meddate
				   and	d.MEDTIME		= in_Medtime
				   and 	e.COMCD1(+)		= '204'
				   and 	e.COMCD2(+)		= '000'
				   and 	e.COMCD3(+)		= d.ERRSLT;
				
		  	exception                    
		     	when no_data_found then	     
	     	
		  			s_ER_Dsch_Rslt 		:= null;
		  	
		  		when others then	     
		  		
		  			s_ER_Dsch_Rslt		:= null;															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#15. 응급정보조사지.ERRSLT failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;  	
		  	
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #16. 퇴원요약지(EMR) 上 퇴원시 상태 Check (미사용)									*/
		  	/*--------------------------------------------------------------------------------------*/		  				 
		  	      
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #17. E/R Sepsis 등록 및 해지 이력유무 (Y: 등록, N: 해지, null: 미체크) Check			*/
		  	/*--------------------------------------------------------------------------------------*/		  				 		  	
		  	begin
		  		select
		  				max(a.RGTYN)
		  		  into
		  		  		s_Sepsis_Yn
		  		  from
		  		  		EGDT환자관리	a
		  		 where
		  		 		a.PATNO		= in_Patno
		  		   and	a.RGTDATE	= in_Meddate		  		   
		  		   and	a.MEDDATE	= in_Meddate
		  		   and	a.MEDTIME	= in_Medtime
		  		   and	a.MEDDEPT	= 'ED'
		  		   and	a.PATSECT	= 'E'	  		   
	  	  		   and	nvl(a.ICUYN, 'N') = 'N';
		  	
		  	exception                  		  			  		
				when no_data_found then	     
	     	
		  			s_Sepsis_Yn 		:= null;
		  	
		  		when others then	     
		  		
		  			s_Sepsis_Yn			:= null;															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#17. EGDT환자관리.RGTYN failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;  
		  	
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #18. SOFA Score 평가일시																*/		  	
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	max(a.ITEMVAL)
				  into
				  		s_Score_EvalTime
				  from
				       	설문항목구성마스터	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSSC'
				   and	a.SETCODE	= 'EC07'			/* SOFA Score 평가일시 */
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_Score_EvalTime 	:= null;							
			   	
				when others then	     
				
					s_Score_EvalTime 	:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#18. SOFA Score 평가일시(설문항목구성마스터) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
							
			end;
			
			
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #19. Sepsis 상병(A41.9) 등록여부														*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	decode(count(a.PATNO), 0, 'N', 'Y')
				  into
				  		s_Seps_Diag_Yn
				  from
				       	환자상병이력	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.MEDDATE 	= in_Meddate
				   and	a.PATSECT	= 'E'
				   and	a.DIAGCD	= 'A41.9';
				       
			exception
			
				when no_data_found then
	
					s_Seps_Diag_Yn 		:= null;							
			   	
				when others then	     
				
					s_Seps_Diag_Yn 		:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#19. Seps. 상병(환자상병이력) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
							
			end;
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #20-1. [M170824-1] MAP 계산위한 SBP/DBP 측정값 조회									*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
			       		nvl(regexp_substr(a.BLDPRESS, '[^/]+', 1, 1), 999)
			       	 ,	nvl(regexp_substr(a.BLDPRESS, '[^/]+', 1, 2), 999)
			  	  into
			  	  		i_Sbp_Erinf
			  	  	 ,	i_Dbp_Erinf
				  from
				       	응급정보조사지	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.MEDDATE 	= in_Meddate
				   and	a.MEDTIME	= in_Medtime;
				       
			exception
			
				when no_data_found then
	
					i_Sbp_Erinf 		:= 999;
					i_Dbp_Erinf 		:= 999;																			
			   	
				when others then	     
				
					i_Sbp_Erinf 		:= 999;
					i_Dbp_Erinf 		:= 999;																			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#20-1. SBP/DBP failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  			  					  			  					  			  					  			  		
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #20-2. [M170824-1] BP 측정값을 토대로 MAP 계산										*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	if	(i_Sbp_Erinf <> 999) 	and	
		  		(i_Dbp_Erinf <> 999)	then
		  	
			  	begin 
			  		select 
			  				round((i_Sbp_Erinf + 2 * i_Dbp_Erinf) / 3, 0)
			  		  into
			  		  		i_Map_Result
					  from 
					  		DUAL;               
					       
				exception
				
					when no_data_found then
		
						i_Map_Result 		:= 999;							
				   	
					when others then	     
					
						i_Map_Result 		:= 999;							
						s_Error_Yn	 		:= 'Y';														
						s_Error_Msg	 		:= '#20-2. MAP failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
								
				end;  
				
			else
			  
				i_Map_Result := 999;
			
			end if;
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #21. [M170824-1] Lactate 1st 실시시간 												*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select  /* Lactic Acid (serum Lactate) E/R 내원후 최초 시행 */
						min(a.EXECDATE)
				  into	
				  		d_Lactic_1st_Time
	              from
	              		검사처방이력	a
	             where
	                    a.PATNO    	= in_Patno
	               and  a.MEDDATE  	= in_Meddate
	               and	a.PATSECT	= 'E'
	               and	a.ORDCD		= 'BM3850'						
	               and 	a.EXECDATE	=	(	
	               							select
	               									min(x.EXECDATE)
	               							  from
	               							  		검사처방이력	x
	               							 where
	               							 		x.PATNO		= a.PATNO
	               							   and	x.MEDDATE	= a.MEDDATE
	               							   and	x.ORDCD		= a.ORDCD
	               							   and	x.DISCYN	is null
	               						)
	               and  a.DISCYN 	is null;
				       
			exception
			
				when no_data_found then
	
					d_Lactic_1st_Time	:= to_date(null);							
			   	
				when others then	     
				
					d_Lactic_1st_Time	:= to_date(null);							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#21. Lactic 1st failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  						  			
		  	

			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #22. [M170824-1] Lactate 2nd 실시시간 												*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	if	(trim(d_Lactic_1st_Time) is not null)	then
		  	
			  	begin 
					select  /* Lactic Acid (serum Lactate) E/R 내원후 최초 시행후 2nd f/u 실시시간 */
							min(a.EXECDATE)
					  into	
					  		d_Lactic_2nd_Time
		              from
		              		검사처방이력	a
		             where
		                    a.PATNO    	= in_Patno
		               and  a.MEDDATE  	= in_Meddate
		               and	a.PATSECT	= 'E'
		               and	a.ORDCD		= 'BM3850'						
		               and 	a.EXECDATE	=	(	
		               							select
		               									min(x.EXECDATE)
		               							  from
		               							  		검사처방이력	x
		               							 where
		               							 		x.PATNO		= a.PATNO
		               							   and	x.MEDDATE	= a.MEDDATE
		               							   and	x.ORDCD		= a.ORDCD
		               							   and	x.EXECDATE	> d_Lactic_1st_Time		/* E/R 내원후 최초 시행이후 2nd f/u */
		               							   and	x.DISCYN	is null
		               						)
		               and  a.DISCYN 	is null;
					       
				exception
				
					when no_data_found then
		
						d_Lactic_2nd_Time 	:= to_date(null);							
				   	
					when others then	     
					
						d_Lactic_2nd_Time 	:= to_date(null);							
						s_Error_Yn	 		:= 'Y';														
						s_Error_Msg	 		:= '#22. Lactic 2nd failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
								
				end;  
				  
			/* E/R 내원후 최초 Lactate acid 시행이력 없으면, 2nd f/u도 null로 간주 */
			else 
			
				d_Lactic_2nd_Time	:= to_date(null);			
			
			end if;
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #23. [M170824-1] 입원후 퇴원시 상태(NEDIS 참조)					  					*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select  						
		                decode(c.MEDRSLT,	'6','사망'
		                                ,	'7','사망'
		                                ,	decode(c.TRANS,	'1','전원'
		                                    	          ,	'2','전원'
		                                        	      ,	'3','전원'
		                                            	  ,	decode(c.DSCHTYPE,	'1','정상퇴원'
		                                                                 	 ,	'2','자의퇴원'
		                                                                 	 ,	'3','탈원'
		                                                                 	 ,	'기타')
		                                        )
		                       )
		           into
		           		s_Dsch_State 
		           from
		           		입원접수이력 	a,
		              	퇴원환자진단관리 	c
		          where
		                a.PATNO		= in_Patno 
		            and	a.ADMDATE	= in_Meddate
		            and	a.DSCHDATE	is not null
		            and c.PATNO 	= a.PATNO
		            and c.DSCHDATE 	= a.DSCHDATE
		            and exists 	(select 
		            					1
		                           from 
		                           		응급정보조사지	x
		                          where 
		                           		x.PATNO   	= a.PATNO
		                            and x.MEDDATE 	between a.ADMDATE
		                                            	and a.ADMIDATE
		                            and x.ERRSLT  	= '1'
		                        );
				       
			exception
			
				when no_data_found then
	
					s_Dsch_State 		:= null;							
			   	
				when others then	     
				
					s_Dsch_State 		:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#23. 퇴원시상태 failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  				

	  		
	  		/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #24. [M170915-1] SOFA Score 평가 최종 등록자(이름) 									*/	  					  	
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	fn_username_select(max(a.EDITID))
				  into
				  		s_Score_RgtNm
				  from
				       	설문항목구성마스터	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSSC'
				   and	a.SETCODE	= 'EC08'			/* SOFA Score 합계 2점이상 유무 */
				   and	a.ITEMVAL	is not null			/* [M171023-1] CPG 2단계 최종평가 여부 필수조건 추가 */
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_Score_RgtNm 		:= null;							
			   	
				when others then	     
				
					s_Score_RgtNm 		:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#24. SOFA Score 최종등록자 Failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  
			
			
	  		/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #25. [M171019-1] Sepsis 번들처방 (기본/검사) 존재유무 (Y/N)							*/	  					  	
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 			
				select
						max(x.SEPSORDYN)
				  into
				  		s_Bundle_Yn
				  from
						(
						select
								decode(count(*), 0, 'N', 'Y')	as	SEPSORDYN
						  from
						  		기본처방이력	a
						 where
						 		a.PATNO   	= in_Patno
						   and 	a.MEDDATE 	= in_Meddate
						   and 	a.MEDTIME 	= in_Medtime
						   and	a.DISCYN	is null
						   and	a.SEPSFLAG	= 'E'
				
						union
				
						select
								decode(count(*), 0, 'N', 'Y')	as	SEPSORDYN
						  from
						  		검사처방이력	a
						 where
						 		a.PATNO   	= in_Patno
						   and 	a.MEDDATE 	= in_Meddate
						   and 	a.MEDTIME 	= in_Medtime
						   and	a.DISCYN	is null
						   and	a.SEPSFLAG	= 'E'
						)	x;
						
			exception
			
				when no_data_found then
	
					s_Bundle_Yn 		:= 'N';							
			   	
				when others then	     
				
					s_Bundle_Yn 		:= 'N';								
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#25. 번들처방 유무 Failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  	
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #26. [M171023-2] Infection 평가 최종 등록자(이름) 									*/	  					  	
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	fn_username_select(max(a.EDITID))
				  into
				  		s_Infection_RgtNm
				  from
				       	설문항목구성마스터	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSIF'
				   and	a.ITEMVAL	is not null			/* [M171023-1] CPG 1단계 최종평가 여부 필수조건 추가 */
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_Infection_RgtNm 	:= null;							
			   	
				when others then	     
				
					s_Infection_RgtNm 	:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#26. Infection 최종등록자 Failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  			
	  	
	  	end if;	/* #3. E/R Sepsis CPG 적용대상만 qSOFA - Infection - 번들처방 - SOFA Score Check 종료 	*/
  	
  	end if;	/* #1-2. 권한 유효하면 계속해서 E/R Sepsis CPG 대상 상세조건 Check 종료		*/
  	
  	          
  	
  	
  	
  	/*------------------------------------------------------------------------------------------------------------------------------*/	    		  
    /* #9-1. 최종 Token 리턴 Value 생성																								*/
  	/*------------------------------------------------------------------------------------------------------------------------------*/
  	
    /* #9-1-1. 전체 CPG 대상 상세내역 Token 반환 : 추후 Token 확장될 수 있음 (길이제한 관련 참조: 토큰 리턴 max-size asciz3h)	*/
  	if	in_Jobtype	=	'ALL_TOKEN'		then	    		  
	             
		if	s_System_Open_Yn = 'Y'	then
		
	  		s_Rtn_Token	:= 	s_ER_Target_Yn 										|| '|' ||			/* 1st Token  - E/R Sepsis CPG 적용대상여부									*/
							to_char(nvl(i_Conscious_Cnt, 0))  					|| '|' ||			/* 2nd Token  - qSOFA #1 - 의식상태 건수 (Alert : 0, 그 외 : 1)				*/
							to_char(nvl(i_SBP_Below100_Cnt, 0))					|| '|' ||			/* 3rd Token  - qSOFA #2 - SBP <= 100 건수 									*/
							to_char(nvl(i_RR_Above22_Cnt, 0))					|| '|' ||			/* 4th Token  - qSOFA #3 - RR  >= 20  건수 									*/
							s_qSOFA_Yn											|| '|' ||			/* 5th Token  - qSOFA 활성화(+) 적용(충족)여부 								*/
							to_char(d_SOFA_Time, 'yyyymmddhh24mi')				|| '|' ||			/* 6th Token  - qSOFA 활성화(+) 적용시간 (응급정보조사지.SOFATIME)				*/	  					  
							s_Infection_Yn			 							|| '|' ||			/* 7th Token  - Infection 등록 유무 (설문항목구성마스터.SETTYPE = ERSIF)				*/
							s_SOFA_Score_Above2									|| '|' ||			/* 8th Token  - SOFA Score 2점 이상 여부 (Y/N)								*/
							s_SOFA_Score_State									|| '|' ||			/* 9th Token  - SOFA Score 저장상태(저장완료: C, 임시저장: T, 미저장: X) 여부	*/ 		
							s_Exm_Token											|| '|' ||			/* 10th Token - Sepsis 번들처방 대상 목록 String	  					  	*/
							s_PaO2_Result										|| '|' ||	  		/* 11th Token - PaO2 (ABGA) 내원후 첫 검사결과								*/
							s_Cr_Result											|| '|' || 			/* 12th Token - Creatinine (Cr) 내원후 첫 검사결과							*/
							s_PLT_Result										|| '|' ||			/* 13th Token - Platelet (PLT) 내원후 첫 검사결과							*/
							s_TBil_Result										|| '|' ||			/* 14th Token - Bilirubin, Total (T.bil) 내원후 첫 검사결과    				*/
							s_Exm_Blood											|| '|' ||			/* 15th Token - Blood Cx. 실시이력 						    				*/
							s_Exm_Urine											|| '|' ||			/* 16th Token - Urine Cx. 실시이력 						    				*/							
							s_Exm_Sputum										|| '|' ||			/* 17th Token - Sputum Cx. 실시이력 					    				*/																												                                             
							to_char(i_Lactate_Cnt)								|| '|' ||			/* 18th Token - Lactate f/u 횟수 											*/
							to_char(i_FstAnti_Diff_Medtime)						|| '|' ||		  	/* 19th Token - 최초 항생제 투여시간 - E/R 내원일시 gap (예: 1, 2.23, ...)  */
							s_ER_Dsch_Rslt										|| '|' ||		  	/* 20th Token - 응급환자정보조사지 퇴실결과                                 */
							s_Dsch_State										|| '|' ||		  	/* 21th Token - 퇴원요약지(EMR) 퇴원시 상태                                 */
							s_Sepsis_Yn											|| '|' ||			/* 22th Token - Sepsis 이력 (Y: 등록, N: 해지, null: 미작성) 유무           */								
							s_Score_EvalTime									|| '|' ||			/* 23th Token - SOFA Score 평가일시	(yyyy-mm-dd hh24:mi)		            */
							s_Seps_Diag_Yn										|| '|' ||			/* 24th Token - Sepsis 상병(A41.9) 등록유무		            				*/								 																				 					
							to_char(i_MAP_Result)								|| '|' ||			/* 25th Token - MAP 계산결과 [M170824-1] 									*/
							to_char(d_Lactic_1st_Time, 'yyyy-mm-dd hh24:mi')	|| '|' ||			/* 26th Token - Lactate 1st 실시시간 [M170824-1]							*/
							to_char(d_Lactic_2nd_Time, 'yyyy-mm-dd hh24:mi')	|| '|' ||			/* 27th Token - Lactate 2nd 실시시간 [M170824-1]							*/
	  					  	s_Dsch_State										|| '|' ||			/* 28th Token - NEDIS 퇴원시 상태 (md_nedis_l1 > 치료결과(의정) 참조) [M170824-1] */
	  					  	s_Score_RgtNm										|| '|' ||			/* 29th Token - CPG 2단계 SOFA Score 평가 최종 등록자(이름) [M170915-1]		*/	  					  	
	  					  	s_Bundle_Yn											|| '|' ||			/* 30th Token - Sepsis 번들처방 (기본/검사) 존재유무 (Y/N)	[M171019-1]		*/
	  						s_Infection_RgtNm;														/* 31th Token - CPG 1단계(Infection) 평가 최종 등록자(이름) [M171023-2] 	*/	  					  
		else
		
			s_Rtn_Token := '';
			
		end if;					
  	   

            
    /* #9-1-2. 응급환자정보조사지 저장(md_erinf_i3)시, qSOFA 활성화 대상여부 반환 */                                       
	elsif	in_Jobtype	=	'qSOFA_ON'	then
	                 
		/* 기존 qSOFA 활성화 시간 미적용중인 경우, qSOFA 활성화 조건체크 결과(s_qSOFA_Yn) 반환 */
		if	trim(d_SOFA_Time)	is null		then
				
			s_Rtn_Token		:=	s_qSOFA_Yn;		
			                       
		/* 기존 qSOFA 활성화 시간 적용중인 경우, CPG 대상아님(N) */
		else
		
			s_Rtn_Token     := 'N';
		
		end if;   
		
    /* #9-1-3. CPG 2단계: SOFA Score 평가시 E/R 내원후 항목별 첫 검사결과 (4종) Token 리턴 	*/
    /* [M170824-1] SOFA Score 평가시 MAP 자동계산 결과 연동 추가 				 			*/
	elsif	in_Jobtype	=	'EXM_RESULT'	then	
	                                               
		s_Rtn_Token	:= 	s_PaO2_Result										|| '|' ||	  		/* 1st Token - PaO2 (ABGA) 내원후 첫 검사결과								*/
						s_Cr_Result											|| '|' || 			/* 2nd Token - Creatinine (Cr) 내원후 첫 검사결과							*/
						s_PLT_Result										|| '|' ||			/* 3rd Token - Platelet (PLT) 내원후 첫 검사결과							*/
						s_TBil_Result 										|| '|' ||			/* 4th Token - Bilirubin, Total (T.bil) 내원후 첫 검사결과    				*/
						to_char(i_MAP_Result);													/* 5th Token - 내원후 첫(최초) MAP 계산결과 [M170824-1]						*/						
		
	end if;
		

	/*------------------------------------------------------------------------------*/	    		  
    /* #9-Y. 체크 단계별 오류 발생시 Logging 적용 									*/
  	/*------------------------------------------------------------------------------*/
  	if	s_Error_Yn	= 'Y'	then
  	       
  		pc_ins_mdsylogt	(
							'FUNC_CHK_ER_SEPSIS_FEATURES'
						,	'SVC'
						,	in_Patno      
			 			,	in_Jobtype || ' Error'
						,	to_char(in_Meddate, 'yyyymmdd') 		|| '|' ||
							to_char(in_Medtime, 'yyyymmddhh24mi') 	|| '|' || 
							in_Option	|| '|' || 							
							'[Result]'  || '|' || 
							s_Rtn_Token || '|' ||
							'[qSOFA]'   || '|' ||
							to_char(i_Conscious_Cnt)	|| '/' ||
							to_char(i_SBP_Below100_Cnt)	|| '/' || 
							to_char(i_RR_Above22_Cnt)  	|| '|' ||
							s_Error_Msg
						); 	 
						           
		
  	end if;					
  	

	/*----------------------------------------------------------------------------------*/	    		  
    /* #9-Z. 최종 value 반환															*/
  	/*----------------------------------------------------------------------------------*/
    return(s_Rtn_Token);    
    
end;

/