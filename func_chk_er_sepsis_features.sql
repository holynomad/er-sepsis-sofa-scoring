CREATE OR REPLACE
function fn_chk_er_sepsis	(	in_Jobtype	in varchar2,	/* �۾����� : 
                                                                            'ALL_TOKEN'	 - E/R Sepsis CPG ��� ������ Token Ȯ�� �� ����
																			'qSOFA_ON' 	 - ���ް�ȣ���������� ����� qSOFA Ȱ��ȭ ������ ���� Ȯ��
																			'EXM_RESULT' - SOFA Score �򰡽� E/R ������ �׸� ù �˻��� Token ����
															*/
								in_Patno 	in varchar2,	/* ȯ�ڹ�ȣ 											*/
                   		   		in_Meddate 	in date,		/* ��������		(yyyymmdd)								*/
                   		   		in_Medtime	in date,		/* �����ð�		(yyyymmddhh24mi)						*/
                   		   		in_Option	in varchar2		/* �ɼ� 		(Ȯ�强 ���) 							*/                   		   		
                   		  	) 	return varchar2	
/*====================================================================================================================
      Program ID      :   func_chk_er_sepsis_features
      Program ��      :   E/R Sepsis CPG (���� ������ȯ�� ǥ��������ħ) ��� �ʼ� ����ó�� �� ������ check
      Program ����    :   ���� EGDT ���μ����� �����ϰ�, ICU Sepsis ���� ���μ����� �����ϰ� E/R CPG ������ 

      					  
	  Return value	  :	  1st Token  - E/R Sepsis CPG �����󿩺� 	(s_ER_Target_Yn)
	  					  2nd Token  - qSOFA #1 - �ǽĻ��� �Ǽ� (Alert : 0, �� �� : 1)(i_Conscious_Cnt)	  					  
	  					  3rd Token  - qSOFA #2 - SBP <= 100 �Ǽ� (i_SBP_Below100_Cnt)
	  					  4th Token  - qSOFA #3 - RR  >= 20  �Ǽ� (i_RR_Above22_Cnt)
	  					  5th Token  - qSOFA Ȱ��ȭ(+) ����(����)���� (s_qSOFA_Yn)	  					  
	  					  6th Token  - qSOFA Ȱ��ȭ(+) ����ð� (��������������.SOFATIME, d_SOFA_Time)	  					  
	  					  7th Token  - Infection ��� ���� (s_Infection_Yn)
	  					  8th Token  - SOFA Score 2�� �̻� ���� (s_SOFA_Score_Above2)
	  					  9th Token  - SOFA Score �������(����Ϸ� vs. �ӽ�����) ���� (s_SOFA_Score_State)	  					  
	  					  10th Token - Sepsis ����ó�� ��� ��� String	  					  
	  					  11th Token - PaO2 (ABGA) ������ ù �˻���
	  					  12th Token - Creatinine (Cr) ������ ù �˻���
	  					  13th Token - Platelet (PLT) ������ ù �˻���
	  					  14th Token - Bilirubin, Total (T.bil) ������ ù �˻���	  					  
	  					  15th Token - Blood Cx �����̷�
	  					  16th Token - Urine Cx �����̷�
	  					  17th Token - Sputum Cx �����̷�
	  					  18th Token - Lactate f/u Ƚ�� 
	  					  19th Token - ���� �׻��� �����ð� - E/R �����Ͻ� (��: 1, 2, ...)
	  					  20th Token - ����ȯ������������ ��ǰ��
	  					  21th Token - ��������(EMR) ����� ����
	  					  22th Token - Sepsis ȯ�� ���/���� �̷�(Y: ���, N: ����, null: �̵��)
	  					  23th Token - SOFA Score ���Ͻ� (yyyy-mm-dd hh24:mi) 
	  					  24th Token - Seps. ��(A41.9) �������
	  					  25th Token - MAP �����
	  					  26th Token - Lactate 1st �ǽýð�
	  					  27th Token - Lactate 2nd �ǽýð�	  					  
	  					  28th Token - NEDIS ����� ���� (MDT005F1 > md_nedis_l1 > ġ����(����) ����)
	  					  29th Token - CPG 2�ܰ�(SOFA Score) �� ���� �����(�̸�)
	  					  30th Token - Sepsis ����ó�� �� ó���̷� ���� (Y/N)                       
	  					  31th Token - CPG 1�ܰ�(Infection) �� ���� �����(�̸�)	  					  
	  					  	  					         					  
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
	  	  Modify		  25th ~ 28th Token �׸� �߰� (MAP, Lactate 1st/2nd �ð�, NEDIS ����û��� ��)
	  	  
	  3.  2017-09-15	  Lee, Se-Ha											M170915-1
	  	  Modify		  29th Token �׸� �߰� (���� SOFA Score �򰡵����)                              	  	                                
	  	  
	  4.  2017-09-25	  Lee, Se-Ha											M170925-1
	  	  Modify		  qSOFA (+) ���� ���� (���ް�ȣ���������� ߾ "������ = �Կ�" ����)
	  	  
	  5.  2017-09-26	  Lee, Se-Ha											M170926-1
	  	  Modify		  E/R ������ ù �˻��� ������ �ε�ȣ(<, >) Ư������ replace ����
	  	  
	  6.  2017-09-26	  Lee, Se-Ha											M170926-2
	  	  Modify		  �˻��� ��ȸ�� Text ���� ��� filtering (fn_isnum) ����
	  	  
	  7.  2017-10-19	  Lee, Se-Ha											M171019-1
	  	  Modify		  30th Token �׸� �߰� (Sepsis ����ó�� �� ó���̷� ���� (Y/N))
	  	  
	  8.  2017-10-23	  Lee, Se-Ha											
	  	  Modify		  CPG 2�ܰ� ������ ���� �ʼ����� �߰� 				M171023-1
	  	  Modify		  31th Token �׸� �߰� (CPG 1�ܰ� ��������)			M171023-2	  	  
	                                                                                     
	  9.  2017-11-24	  Lee, Se-Ha											M171124-1
	  	  Modify		  �������������� ������� qSOFA �Ǵ�����(�ǽ�/SBP/RR) 
	  	  				  ���Էµ� ��� nvl ����
	  	  				  
	  10. 2017-11-27	  Lee, Se-Ha											M171127-1
	  	  Modify		  �������������� ����� qSOFA �Ǵ����� �� SBP ���Էµ� ��� 
	  	  				  ��������( <= 100) nvl ���� 
	  	  				  
	  11. 2017-11-30	  Lee, Se-Ha											M171130-1
	  	  Modify		  �������������� ����� UMLS ������ CPR ��ϵ� ȯ�ڴ�
	  	  				  qSOFA Ȱ��ȭ ��󿡼� ���� 
	  	  				  
	  12. 2018-02-01	  Lee, Se-Ha											M180201-1
	  	  Modify		  �������������� �ǽĻ���(CONSSTAT) üũ ���� ����(Alert ������ ��� 1 ����) 
	  	  
	  13. 2018-02-14	  Lee, Se-Ha											M180214-1
	  	  Modify		  �������������� UMLS ������ DOA�� qSOFA Ȱ��ȭ ��� ���� 
	  	  	          
 =====================================================================================================================*/                        	                     		 
is    
	s_Locate				varchar2(2)		:= fn_getlocate;									/* ���� ����		 */
    s_Rtn_Token				varchar2(500)	:= null;     										/* ���� Return Token */
          
    s_System_Open_Yn		varchar2(1)		:= 'N';												/* E/R Sepsis ������ ���� D/B ����								*/          
    s_ER_Target_Yn			varchar2(1)		:= 'N';												/* E/R Sepsis CPG �����󿩺� (default : N)				 	*/             
    
    i_Conscious_Cnt			number(1)		:= 0;	                 							/* qSOFA #1 - �ǽĻ��� �Ǽ� (Alert : 0, �� �� : 1) 				*/
    i_SBP_Below100_Cnt		number(1)		:= 0;												/* qSOFA #2 - SBP <= 100 �Ǽ�									*/
    i_RR_Above22_Cnt		number(1)		:= 0;												/* qSOFA #3 - RR  >= 20  �Ǽ�									*/    
    s_qSOFA_Yn				varchar2(1)		:= 'N';												/* qSOFA Ȱ��ȭ(+) ���(����) ����								*/    
                                                                                                                       
    d_SOFA_Time				date			:= to_date(null);									/* qSOFA Ȱ��ȭ �ð�(��������������.SOFATIME)							*/
    
    s_Infection_Yn			varchar2(1)		:= null;											/* Infection ���� (No Infection : N, �� �� : Y)					*/
    s_SOFA_Score_Above2		varchar2(1)		:= null;											/* SOFA Score �հ� 2���̻� ���� (Y/N)							*/
    s_SOFA_Score_Exists		varchar2(1)		:= null;											/* SOFA Score �̷� ���翩�� (Y/N)								*/
    s_SOFA_Score_State		varchar2(1)		:= null;											/* SOFA Score �������(����Ϸ� (C) vs. �ӽ����� (T))			*/

    s_Exm_Blood				varchar2(2)		:= 'XX';											/* Culture & Blood �ǽ��̷� (�˻� 2)							*/    
    s_Exm_Urine				varchar2(2)		:= 'XX';											/* Culture(�񴢱��ü) �ǽ��̷� (�˻� 2)						*/                
    s_Exm_Sputum			varchar2(2)		:= 'XX';											/* Culture(ȣ����ü) �ǽ��̷� (�˻� 2)						*/                
    s_Exm_Token				varchar2(40)	:= 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';		/* E/R Sepsis ����ó��(�˻�) ���� Token (���½��� 40�ڸ� : ��������ڵ�.COMCD1 = 754, COMCD2 = ERSEPS% ����) */
                
	s_PaO2_Result			varchar2(10)	:= null;				  					  		/* PaO2 (ABGA) ������ ù �˻���								*/
	s_Cr_Result				varchar2(10)	:= null;				  					  		/* Creatinine (Cr) ������ ù �˻���							*/
	s_PLT_Result			varchar2(10)	:= null;				  					  		/* Platelet (PLT) ������ ù �˻���							*/
	s_TBil_Result			varchar2(10)	:= null;				  					  		/* Bilirubin, Total (T.bil) ������ ù �˻���    				*/

	d_FstAnti_Acttime       date			:= to_date(null);									/* ���� �׻��� �����ð�											*/
	
	i_Lactate_Cnt			number(1)		:= 0;												/* E/R ������ Lactate f/u Ƚ��									*/
	i_FstAnti_Diff_Medtime	number(10)		:= 999;												/* ���� �׻��� �����ð� - E/R �����Ͻ� gap (��: 1, 2.23, ...)	*/

	
	s_ER_Dsch_Rslt			varchar2(10)	:= null;											/* ����ȯ������������ ��ǰ�� 									*/
	
	s_Sepsis_Yn				varchar2(1)		:= null;											/* Sepsis �̷�(EGDTȯ�ڰ���.RGTYN) ���� (Y: ���, N: ����, �׿�:null) */
	
	s_Score_EvalTime		varchar2(20)	:= null;											/* SOFA Score ���Ͻ� 											*/
	s_Seps_Diag_Yn			varchar2(10)	:= null;											/* Sepsis ��(A41.7) ������� 									*/
	
	s_Error_Yn				varchar2(1)		:= 'N';												/* üũ �ܰ躰 ���� �α�� ���� #1								*/
	s_Error_Msg				varchar2(500)	:= null;											/* üũ �ܰ躰 ���� �α��(�󼼳���) ���� #2					*/	
		
	i_MAP_Result			number(6)		:= 999;												/* [M170824-1] E/R ������ ù(����) ���� MAP �����			*/							
	d_Lactic_1st_Time		date			:= to_date(null);									/* [M170824-1] E/R ������ ����(1st) Lactate �ǽýð�			*/
	d_Lactic_2nd_Time		date			:= to_date(null);									/* [M170824-1] E/R ������ 2nd Lactate �ǽýð�					*/
	s_Dsch_State			varchar2(20)	:= null;											/* [M170824-1] NEDIS ����� ���� (ġ����(����) ����)	*/																
	i_Sbp_Erinf				number(6)		:= 999;												/* [M170824-1] ��������������(BLDPRESS) SBP ����ġ		*/
	i_Dbp_Erinf				number(6)		:= 999;												/* [M170824-1] ��������������(BLDPRESS) DBP ����ġ		*/
	
	s_Score_RgtNm			varchar2(10)	:= null;											/* [M170915-1] CPG 2�ܰ� SOFA Score �� ���� �����(�̸�)		*/	
	s_Bundle_Yn				varchar2(1)		:= 'N';												/* [M171019-1] Sepsis ����ó�� �� ó���̷� ���� (Y/N)			*/  
	s_Infection_RgtNm		varchar2(10)	:= null;											/* [M171023-2] CPG 1�ܰ� Infection �� ���� �����(�̸�)		*/		
    
begin   
	/*----------------------------------------------------------------------------------*/	    		  
    /* #1-1. E/R Sepsis CPG ������ ���� D/B ���� Check									*/
  	/*----------------------------------------------------------------------------------*/
  	begin
		select
				decode(count(a.COMCDNM3), 0, 'N', 'Y')	/* D/B ���� ���½� DELDATE Ǯ���� ��! */									
		  into
		  		s_System_Open_Yn
      	  from
               	��������ڵ�	a
         where
               	a.COMCD1   	= 'DEPT'     				/* �����ڵ�1 */
           and 	a.COMCD2   	= 'MDP130_SEPSIS'			/* �����ڵ�2 */	
           and	a.COMCD3	= 'ALL'						/* �����ڵ�3 : ALL - �ش纴�� ��ü */	
           and 	a.DELDATE is null;
	
  	exception
  	
  		when no_data_found then

			s_System_Open_Yn  := 'N';							
	   	
		when others then	     
		
			s_System_Open_Yn  := 'X';					/* Set error flag : X */
  	
  	end;	          
  	
   
	/*----------------------------------------------------------------------------------*/	    		  
  	/* #1-2. ���� ��ȿ�ϸ� ����ؼ� E/R Sepsis CPG ������ Check ����					*/
  	/*----------------------------------------------------------------------------------*/
  	if	s_System_Open_Yn = 'Y'	then	                                                  
  	
  	    
  	    /*------------------------------------------------------------------------------*/	    		  
	  	/* #2-1. E/R Sepsis CPG ������ ���� Ȯ��	 									*/
	  	/*------------------------------------------------------------------------------*/		
		begin
	  	    select
			     	decode(count(a.PATNO), 0, 'N', 'Y')
			  into
			  		s_ER_Target_Yn
			  from
			       	��������������	a,
			       	ȯ�ڸ�����	b
			 where
			       	a.PATNO   	= in_Patno
			   and 	a.MEDDATE 	= in_Meddate
			   and 	a.MEDTIME 	= in_Medtime
			   /* and 	nvl(a.ERRSLT, '*') = '1' */						/* ���ް�ȣ���������� - ���޼��� ��ǰ�� : �Կ� --> [M170925-1] ��� ���� ���� */
			   and 	a.INRSN1 	= '1'                   				/* ���ް�ȣ���������� - �������� : ����				*/
			   and 	b.PATNO 	= a.PATNO
			   and 	floor((a.MEDDATE - b.BIRTDATE) / 365) >= 15; 		/* �� 15�� �̻�										*/
        
		exception
	  	
	  		when no_data_found then
	
				s_ER_Target_Yn  := 'N';							
		   	
			when others then	     
			
				s_ER_Target_Yn 	:= 'X';														
				s_Error_Yn	 	:= 'Y';														
				s_Error_Msg	 	:= '#2-1. E/R CPG ��󿩺� failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
	  	
	  	end; 
	  	
	  	
		/*------------------------------------------------------------------------------------------*/	    		  
	  	/* #2-2. qSOFA Ȱ��ȭ ����ð� üũ (SOFATIME)										*/		  	
	  	/* 		- [M171023-3] ���� SOFA Ȱ��ȭ ���� [��������]�� �������� ������ �� ����� ��쵵	*/
	  	/*		  ���� Sepsis ���̷� ��ȸ�� ����͸� �ϱ� ���� #5���� #2-2�� üũ ����	*/
	  	/*------------------------------------------------------------------------------------------*/			  		  				  	
	  	begin 
			select
			       	a.SOFATIME
			  into
			  		d_SOFA_Time
			  from
			       	��������������	a
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
	  	/* #3. E/R Sepsis CPG ������ qSOFA > Infection > ����ó�� > SOFA Score Check ���� 	*/
	  	/* 		- [M171023-3] qSOFA Ȱ��ȭ ���� CPG ������ ���� ����� case�� CPG �̷���ȸ 	*/
	  	/*--------------------------------------------------------------------------------------*/		
	  	if	(s_ER_Target_Yn		=	'Y')	or
	  		(d_SOFA_Time	is not null)	then
	  	    
	  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #4-1. qSOFA Ȱ��ȭ ���� #1 : �ǽĻ��� (Alert �� ������ �ش�� Y, ���ް�ȣ����������)	*/
		  	/*--------------------------------------------------------------------------------------*/			  	
		  	begin
				select
				       	nvl(count(a.CONSSTAT), 0)
				  into
				  		i_Conscious_Cnt
				  from
				       	��������������	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.MEDDATE 	= in_Meddate
				   and 	a.MEDTIME 	= in_Medtime
				   and  nvl(a.CONSSTAT, 'A')	<> 'A'	/* in ('V', 'P', 'D') */			/* �ǽĻ��� alert ���� --> [M180201-1] Alert�� ������ ��� �ǽĻ��� üũ(UnResponsive ����) */				         	
				       																		/* [M171124-1] �������������� ��������� �ǽĻ��� ���Է� �� �� �ֱ� ������ nvl ó�� */
				   and	not exists  (  	/* [M171130-1] UMLS ������ CPR �� DOA ��ϵ� ȯ�ڴ� qSOFA Ȱ��ȭ ���� ���ǿ��� ���� */
				   						select
				   								'CPR'
				   						  from
				   						  		��ȣ�Ҹ�����	x
				   						 where
				   						 		x.PATNO		= a.PATNO
				   						   and	x.MEDDATE	= a.MEDDATE
				   						   and	x.MEDTIME	= a.MEDTIME
				   						   and	(
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0007203') or	/* UMLS ������1 CPR ��� */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0007203') or    /* UMLS ������2 CPR ��� */
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0007203') or	/* UMLS ������3 CPR ��� */
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0421619') or	/* [M180214-1] UMLS ������1 DOA ��� */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0421619') or	/* [M180214-1] UMLS ������2 DOA ��� */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0421619') 		/* [M180214-1] UMLS ������3 DOA ��� */ 				   						   							   						   								   						   							   						   			 				   						   							   						   				
				   						   		)
				   					);
				   					
				       
			exception
			
				when no_data_found then
	
					i_Conscious_Cnt := 0;							
			   	
				when others then	     
				
					i_Conscious_Cnt := 0;
					s_Error_Yn	 	:= 'Y';														
					s_Error_Msg	 	:= '#4-1. �ǽĻ��� failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
					
			end;
            
			
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #4-2. qSOFA Ȱ��ȭ ���� #2 : SBP <= 100 (���ް�ȣ����������)						 	*/
		  	/*--------------------------------------------------------------------------------------*/			  		  		
		  	begin   
				select
				       	nvl(count(a.PATNO), 0)
				  into
				  		i_SBP_Below100_Cnt
				  from
				       	��������������	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.MEDDATE 	= in_Meddate
				   and 	a.MEDTIME 	= in_Medtime
				   and 	nvl(regexp_substr(a.BLDPRESS, '[^/]+', 1, 1), 10) <= 100		/* SBP <= 100 */
				   																		/* [M171124-1] �������������� ��������� BP ���Է� �� �� �ֱ� ������ nvl ó�� */
				   																		/* [M171127-1] �������������� ��������� BP ���Է½� Ȱ��ȭ ����(<= 100) nvl ó�� */
				   and	not exists  (  	/* [M171130-1] UMLS ������ CPR �� DOA ��ϵ� ȯ�ڴ� qSOFA Ȱ��ȭ ���� ���ǿ��� ���� */
				   						select
				   								'CPR'
				   						  from
				   						  		��ȣ�Ҹ�����	x
				   						 where
				   						 		x.PATNO		= a.PATNO
				   						   and	x.MEDDATE	= a.MEDDATE
				   						   and	x.MEDTIME	= a.MEDTIME
				   						   and	(
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0007203') or	/* UMLS ������1 CPR ��� */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0007203') or    /* UMLS ������2 CPR ��� */
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0007203') or	/* UMLS ������3 CPR ��� */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0421619') or	/* [M180214-1] UMLS ������1 DOA ��� */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0421619') or	/* [M180214-1] UMLS ������2 DOA ��� */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0421619') 		/* [M180214-1] UMLS ������3 DOA ��� */				   						   			
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
		  	/* #4-3. qSOFA Ȱ��ȭ ���� #3 : RR >= 20 (���ް�ȣ����������)						 	*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	nvl(count(a.RESPCNT), 0)
				  into
				  		i_RR_Above22_Cnt
				  from
				       	��������������	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.MEDDATE 	= in_Meddate
				   and 	a.MEDTIME 	= in_Medtime
				   and 	nvl(a.RESPCNT, 0) 	>= 22                                 	/* ȣ��� >= 22 */
																				   	/* [M171124-1] �������������� ��������� RR ���Է� �� �� �ֱ� ������ nvl ó�� */
				   and	not exists  (  	/* [M171130-1] UMLS ������ CPR �� DOA ��ϵ� ȯ�ڴ� qSOFA Ȱ��ȭ ���� ���ǿ��� ���� */
				   						select
				   								'CPR'
				   						  from
				   						  		��������������	x
				   						 where
				   						 		x.PATNO		= a.PATNO
				   						   and	x.MEDDATE	= a.MEDDATE
				   						   and	x.MEDTIME	= a.MEDTIME
				   						   and	(
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0007203') or	/* UMLS ������1 CPR ��� */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0007203') or    /* UMLS ������2 CPR ��� */
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0007203') or	/* UMLS ������3 CPR ��� */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD1, '*')	= 'C0421619') or	/* [M180214-1] UMLS ������1 DOA ��� */
				   						   			(nvl(x.SYMPTCD2, '*')	= 'C0421619') or	/* [M180214-1] UMLS ������2 DOA ��� */ 				   						   							   						   				
				   						   			(nvl(x.SYMPTCD3, '*')	= 'C0421619') 		/* [M180214-1] UMLS ������3 DOA ��� */				   						   			
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
		  	/* #4-4. qSOFA Ȱ��ȭ ���� �Ǵ� : �� 3���� �׸��� 2���� �̻� �ش�Ǹ�, CPG ���(+)	 	*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  			  	
		  	if	i_Conscious_Cnt + i_SBP_Below100_Cnt + i_RR_Above22_Cnt >= 	2	then

		  		s_qSOFA_Yn		:= 'Y';		  		
		  	       
		  	else
		  		
		  		s_qSOFA_Yn		:= 'N';
		  	
		  	end if;       
		  	
		       
			/*------------------------------------------------------------------------------------------*/	    		  
		  	/* #5. qSOFA Ȱ��ȭ ����ð� üũ (��������������.SOFATIME)										*/		  	
		  	/* 		- [M171023-3] ���� SOFA Ȱ��ȭ ���� [��������]�� �������� ������ �� ����� ��쵵	*/
		  	/*		  ���� Sepsis ���̷� ��ȸ�� ����͸� �ϱ� ���� #2-2�� ���� ����			*/
		  	/*		- ���� �����帧 �����丮 ���� ���� �ߺ� ����(#2-2 �� %5) �׳� ���� -_-;				*/  
		  	/*------------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	a.SOFATIME
				  into
				  		d_SOFA_Time
				  from
				       	��������������	a
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
					s_Error_Msg	 		:= '#5. ��������������.SOFATIME failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
							
			end;        		
		

			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #6. Infection ��� ���� (Y/N)														*/		  	
		  	/*--------------------------------------------------------------------------------------*/			  				        		  	
		  	begin 
				select
				       	max(case when a.ITEMVAL = 'Y' then 'N' else 'Y' end)		/* No Infection (EF99)�� ��� N, ������ �����ϸ� Y */
				  into
				  		s_Infection_Yn
				  from
				       	�����׸񱸼�������	a
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
					s_Error_Msg	 		:= '#6. Infection (�����׸񱸼�������) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
								
			end;  
		  	   
		  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #7-1. SOFA Score ������ 2���̻� ���� (Y/N)											*/		  	
		  	/*--------------------------------------------------------------------------------------*/			
            begin 
				select
				       	decode(max(a.ITEMVAL), 'Yes', 'Y', 'No', 'N', null)					
				  into
				  		s_SOFA_Score_Above2
				  from
				       	�����׸񱸼�������	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSSC'
				   and	a.SETCODE	= 'EC08'			/* SOFA Score �հ� 2���̻� ���� */
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_SOFA_Score_Above2		:= null;							
			   	
				when others then	     
				
					s_SOFA_Score_Above2	  	:= null;							
					s_Error_Yn	 			:= 'Y';														
					s_Error_Msg	 			:= '#7-1. SOFA Score �հ� 2���̻����� (�����׸񱸼�������) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
								
			end;  
			

			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #7-2-1. SOFA Score �� ���翩�� (Y/N)												*/
		  	/*--------------------------------------------------------------------------------------*/					  	
			begin 
				select
				       	decode(count(a.PATNO), 0, 'N', 'Y')
				  into
				  		s_SOFA_Score_Exists
				  from
				       	�����׸񱸼�������	a
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
					s_Error_Msg	 			:= '#7-2-1. SOFA Score ���̷�(�����׸񱸼�������) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
													
			end;  		
			
			  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #7-2-2. SOFA Score �� ������� ����												*/
		  	/*--------------------------------------------------------------------------------------*/					  	
			if	s_SOFA_Score_Exists	= 	'Y'	then
			       
				/* SOFA Score �̷�������, [�հ� 2���̻� ����] �׸� ��üũ �� ��� : �ӽ�����(T) */
				if	Trim(s_SOFA_Score_Above2)	is null		then
				       
					s_SOFA_Score_State	:= 'T';
				
				/* SOFA Score �̷��ְ�, [�հ� 2���̻� ����] �׸� üũ �� ��� : ����Ϸ�(C) */				
				else

					s_SOFA_Score_State	:= 'C';				
				
				end if;			

			/* SOFA Score �̷¾��� ��� : �̵�� (X) */							
			else                                            
			
				s_SOFA_Score_State	:= 'X';										
			
			end if;
			         
						  	
			  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #8. Sepsis Bundle ó�� Token ���� 													*/		  	
		  	/* �� ICU Sepsis�� �ٸ��� �׳� default�� �⺻ ������ (D/B) �־��ְ�,                  */
		  	/*    �ǻ���� �˾Ƽ� �����ϵ��� ����....(������ �ٸ� S/R���� Ŀ���� �� ����..) �� 		*/		  			  	
		  	/*--------------------------------------------------------------------------------------*/
		  	
		  	

			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #9-1. E/R ������ ù ABGA (PaO2) �˻��� ����										*/		  			  			  	
		  	/*--------------------------------------------------------------------------------------*/		  	
		  	begin
	            select
						/* [M170926-1] �˻����� �ε�ȣ(<, >) �Էµ� ��� �߰ߵǾ� replace ���� */                                                                        
						/* [M170926-2] �˻����� Text �Էµ� �༮���� ���Ƽ�...�ε�ȣ �ɷ�����, fn_isnum���� �������Կ��� filtering */
						decode(fn_isnum(max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', '')))), 0, '', max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', ''))))
				  into
				  		s_PaO2_Result
				  from
				  		�˻�ó���̷�	a
				  	 ,	�˻����̷�	b
				 where  				 		
				 		a.PATNO		= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime
				   and	a.DISCYN	is null
				   and	a.ORDCD		= 'BM38150'
				   and	a.EXECDATE	= (
				   							select	/* ���� ���� */
				   									min(x.EXECDATE)
				   							  from
				   							  		�˻�ó���̷�	x
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
					s_Error_Msg	 		:= '#9-1. ABGA (PaO2, �˻����̷�.RSLT1) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
			end;  	
								   
		  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #9-2. E/R ������ ù Creatinine (Cr) �˻���	����									*/
		  	/*--------------------------------------------------------------------------------------*/		  			  	
		  	begin
	            select
						/* [M170926-1] �˻����� �ε�ȣ(<, >) �Էµ� ��� �߰ߵǾ� replace ���� */                                                                        
						/* [M170926-2] �˻����� Text �Էµ� �༮���� ���Ƽ�...�ε�ȣ �ɷ�����, fn_isnum���� �������Կ��� filtering */
						decode(fn_isnum(max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', '')))), 0, '', max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', ''))))
				  into
				  		s_Cr_Result
				  from
				  		�˻�ó���̷�	a
				  	 ,	�˻����̷�	b
				 where  				 		
				 		a.PATNO		= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime
				   and	a.DISCYN	is null
				   and	a.ORDCD		= 'BM37500'
				   and	a.EXECDATE	= (
				   							select	/* ���� ���� */
				   									min(x.EXECDATE)
				   							  from
				   							  		�˻�ó���̷�	x
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
					s_Error_Msg	 		:= '#9-2. Creatinine (Cr, �˻����̷�.RSLT1) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
			end; 
			 	
		  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #9-3. E/R ������ ù Platelet (PLT) �˻���	����									*/
		  	/*--------------------------------------------------------------------------------------*/		  			  			  	
		  	begin
	            select                                                                                                                                                     
						/* [M170926-1] �˻����� �ε�ȣ(<, >) �Էµ� ��� �߰ߵǾ� replace ���� */                                                                        
						/* [M170926-2] �˻����� Text �Էµ� �༮���� ���Ƽ�...�ε�ȣ �ɷ�����, fn_isnum���� �������Կ��� filtering */
						decode(fn_isnum(max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', '')))), 0, '', max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', ''))))
				  into
				  		s_PLT_Result
				  from
				  		�˻�ó���̷�	a
				  	 ,	�˻����̷�	b
				 where  				 		
				 		a.PATNO		= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime
				   and	a.DISCYN	is null
				   and	a.ORDCD		= 'GEML106'
				   and	a.EXECDATE	= (
				   							select	/* ���� ���� */
				   									min(x.EXECDATE)
				   							  from
				   							  		�˻�ó���̷�	x
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
					s_Error_Msg	 		:= '#9-3. Platelet (PLT, �˻����̷�.RSLT1) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
			end; 
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #9-4. E/R ������ ù Bilirubin, Total (T.bil) �˻��� ����							*/
		  	/*--------------------------------------------------------------------------------------*/		  					  	
		  	begin
	            select
						/* [M170926-1] �˻����� �ε�ȣ(<, >) �Էµ� ��� �߰ߵǾ� replace ���� */                                                                        
						/* [M170926-2] �˻����� Text �Էµ� �༮���� ���Ƽ�...�ε�ȣ �ɷ�����, fn_isnum���� �������Կ��� filtering */
						decode(fn_isnum(max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', '')))), 0, '', max(trim(replace(trim(replace(b.RSLT1, '<', '')), '>', ''))))
				  into
				  		s_TBil_Result
				  from
				  		�˻�ó���̷�	a
				  	 ,	�˻����̷�	b
				 where  				 		
				 		a.PATNO		= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime
				   and	a.DISCYN	is null
				   and	a.ORDCD		= 'BM37200'
				   and	a.EXECDATE	= (
				   							select	/* ���� ���� */
				   									min(x.EXECDATE)
				   							  from
				   							  		�˻�ó���̷�	x
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
					s_Error_Msg	 		:= '#9-4. Bilirubin, Total (T.bil, �˻����̷�.RSLT1) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
			end; 
		  	
                  
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #10. Blood Cx, ȣ��/���� ó��/�ǽ� �̷� Check										*/
		  	/*--------------------------------------------------------------------------------------*/		  			           
		  	begin
				select  /* E/R �������� �ǽ��̷� ������ Y, �̽ǽô� N, ��ó��� X */   
						nvl(max(decode(a.ORDCD,	'BN41440',	case when (a.EXECDATE is not null) then 'Y' else 'N' end)),   'X')	||	/* Culture & Sensitivity(blood),Aerobic  (ȣ��)				*/
						nvl(max(decode(a.ORDCD,	'BN41490',	case when (a.EXECDATE is not null) then 'Y' else 'N' end)),   'X')		/* Culture & Sensitivity(blood),Anaerobic(����)				*/
				  into
				  		s_Exm_Blood
	              from    
	              		�˻�ó���̷�	a
	             where
	                    a.PATNO    	= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime                                                          
	               and	a.ORDCD		in 	(	               		
	               							'BN41440',				/* Culture & Sensitivity(blood),Aerobic	 (ȣ��) 	*/
	               							'BN41490'				/* Culture & Sensitivity(blood),Anaerobic(����)		*/               							
	               						)
	               and  a.DISCYN 	is null;
	               
	     	exception                    
		     	when no_data_found then	     
	     	
		  			s_Exm_Blood 		:= 'XX';
		  	
		  		when others then	     
		  		
		  			s_Exm_Blood			:= 'XX';															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#10. Blood Cx (�˻�ó���̷�) �ǽ��̷� failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;                                                                                                      
		  	
		  	
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #11. Urine Cx ó��/�ǽ� �̷� Check													*/
		  	/*--------------------------------------------------------------------------------------*/		  			           
		  	begin
				select  /* E/R �������� �ǽ��̷� ������ Y, �̽ǽô� N, ��ó��� X */   
						nvl(max(decode(a.ORDCD,	'BN4101Z',	case when (a.EXECDATE is not null) and (a.SPCCODE1 = 'C13') then 'Y' else 'N' end)), 'X')	||	/* Gram's stain [Urine] 			 		*/
						nvl(max(decode(a.ORDCD,	'BN41430Z',	case when (a.EXECDATE is not null) and (a.SPCCODE1 = 'C13') then 'Y' else 'N' end)), 'X')		/* Culture(�񴢱�) & Antibiotic MIC			*/
				  into
				  		s_Exm_Urine
	              from    
	              		�˻�ó���̷�	a
	             where
	                    a.PATNO    	= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime                                                          
	               and	a.ORDCD		in 	(	               		
	               							'BN4101Z',				/* Gram's stain 							*/               							
	               							'BN41430Z'				/* Culture(�񴢱�) & Antibiotic MIC			*/
	               						)
	               and  a.DISCYN 	is null;
	               
	     	exception                    
		     	when no_data_found then	     
	     	
		  			s_Exm_Urine 		:= 'XX';
		  	
		  		when others then	     
		  		
		  			s_Exm_Urine			:= 'XX';															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#11. Urine Cx (�˻�ó���̷�) �ǽ��̷� failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;               		  	
		  	      
		  	      
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #12. Sputum Cx ó��/�ǽ� �̷� Check													*/
		  	/*--------------------------------------------------------------------------------------*/		  			           
		  	begin
				select  /* E/R �������� �ǽ��̷� ������ Y, �̽ǽô� N, ��ó��� X */   
						nvl(max(decode(a.ORDCD,	'BN4101Z',	case when (a.EXECDATE is not null) and (a.SPCCODE1 = 'A07') then 'Y' else 'N' end)), 'X')	||	/* Gram's stain [Sputum] 			 		*/
						nvl(max(decode(a.ORDCD,	'BN41410Z',	case when (a.EXECDATE is not null) and (a.SPCCODE1 = 'A07') then 'Y' else 'N' end)), 'X')		/* Culture(ȣ���) & Antibiotic MIC			*/
				  into
				  		s_Exm_Sputum
	              from    
	              		�˻�ó���̷�	a
	             where
	                    a.PATNO    	= in_Patno
				   and	a.MEDDATE	= in_Meddate
				   and	a.MEDTIME	= in_Medtime                                                          
	               and	a.ORDCD		in 	(	               		
	               							'BN4101Z',				/* Gram's stain 							*/               							
	               							'BN41410Z'				/* Culture(ȣ���) & Antibiotic MIC			*/
	               						)
	               and  a.DISCYN 	is null;
	               
	     	exception                    
		     	when no_data_found then	     
	     	
		  			s_Exm_Sputum 		:= 'XX';
		  	
		  		when others then	     
		  		
		  			s_Exm_Sputum		:= 'XX';															  			
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#12. Sputum Cx (�˻�ó���̷�) �ǽ��̷� failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;  		  	                                                                                                            
		  
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #13. Lactate f/u Ƚ�� Check															*/
		  	/*--------------------------------------------------------------------------------------*/		  			           
		  	begin        
			  	select  /* E/R �������� �ǽõ� Lactate �˻� Count */   
						count(a.PATNO)
				  into
				  		i_Lactate_Cnt
	              from    
	              		�˻�ó���̷�	a
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
					s_Error_Msg	 		:= '#13. Lactate (�˻�ó���̷�) �ǽ��̷� failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;  		  	 
		  			  	  				  	
		
		    /*--------------------------------------------------------------------------------------*/	    		  
		  	/* #14-1. ���� �׻��� �����ð� Check													*/
		  	/*--------------------------------------------------------------------------------------*/		  			
		  	begin
				select	
				       	min(to_date(to_char(c.ACTDATE, 'yyyymmdd') || nvl(replace(c.ACTTIME2, ':', ''), replace(c.ACTTIME, ':', '')), 'yyyymmddhh24mi'))
				  into
				  		d_FstAnti_Acttime
				  from
				       	�����̷� 	a
				  	 ,	ó���ڵ帶���� 	b
				     ,	��ȣActing 	c				   
				 where
				       	a.PATNO   		= in_Patno
				   and	a.MEDDATE		= in_Meddate
				   and	a.MEDTIME		= in_Medtime
				   and	a.PATSECT		= 'E'
				   and 	a.DISCYN		is null
				   and 	b.ORDCD    		= a.ORDCD								   
				   and 	b.ORDGRP   		like 'B%'
				   and 	b.DRUGKIND 		in	(
												'4',					/* ������ �׻��� 						*/
		           								'5'						/* ���� �׻���(�������������ڵ�.LARGCD = SD01) 	*/				   			
			         						)
				   and 	c.PATNO			= a.PATNO
				   and 	c.ORDDATE		= a.ORDDATE
				   and 	c.ORDSEQNO		= a.ORDSEQNO
				   and 	c.ACTTYPE		in (    /* �Ʒ� ACTTYPE E/R ����ȣ�� ���� */
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
					s_Error_Msg	 		:= '#14. ���� �׻��� �����ð�(��ȣActing) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;    		  	 
		  	
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #14-2. ���� �׻��� �����ð� - �����Ͻ�(in_Medtim) gap								*/
		  	/*--------------------------------------------------------------------------------------*/		  			
		  	if	Trim(d_FstAnti_Acttime) is not null	then
		  	                                                                               
		  		/* ��(min)�� �ð�(hour)������ ȯ���Ͽ� �Ҽ��� ��° �ڸ��� �ݿø� ����, ǥ�� (��: 10.08�ð�) */
		  		/* [M170824-1] �ð�(hour)���� ��(min)������ ǥ�� ���� ��û  */
		  		/* i_FstAnti_Diff_Medtime := round((d_FstAnti_Acttime - in_Medtime), 2) * 24; */
		  		i_FstAnti_Diff_Medtime := round(d_FstAnti_Acttime - in_Medtime, 2) * 24 * 60;
		  		
		  	else
		  		
		  		i_FstAnti_Diff_Medtime := 999;		  		
		  	
		  	end if;
		  	
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #15. ����ȯ�� ���������� ߾ ��ǰ�� Check											*/
		  	/*--------------------------------------------------------------------------------------*/		  			
		  	begin
				select				      
					 	e.COMCDNM3		/* ���޽� ��ǰ�� */
				  into
				  		s_ER_Dsch_Rslt
				  from 					       
				     	�������������� 		d
				     ,	��������ڵ� 		e
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
					s_Error_Msg	 		:= '#15. ��������������.ERRSLT failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;  	
		  	
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #16. ��������(EMR) ߾ ����� ���� Check (�̻��)									*/
		  	/*--------------------------------------------------------------------------------------*/		  				 
		  	      
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #17. E/R Sepsis ��� �� ���� �̷����� (Y: ���, N: ����, null: ��üũ) Check			*/
		  	/*--------------------------------------------------------------------------------------*/		  				 		  	
		  	begin
		  		select
		  				max(a.RGTYN)
		  		  into
		  		  		s_Sepsis_Yn
		  		  from
		  		  		EGDTȯ�ڰ���	a
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
					s_Error_Msg	 		:= '#17. EGDTȯ�ڰ���.RGTYN failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
		  	end;  
		  	
		  	
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #18. SOFA Score ���Ͻ�																*/		  	
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	max(a.ITEMVAL)
				  into
				  		s_Score_EvalTime
				  from
				       	�����׸񱸼�������	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSSC'
				   and	a.SETCODE	= 'EC07'			/* SOFA Score ���Ͻ� */
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_Score_EvalTime 	:= null;							
			   	
				when others then	     
				
					s_Score_EvalTime 	:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#18. SOFA Score ���Ͻ�(�����׸񱸼�������) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
							
			end;
			
			
		  	/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #19. Sepsis ��(A41.9) ��Ͽ���														*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	decode(count(a.PATNO), 0, 'N', 'Y')
				  into
				  		s_Seps_Diag_Yn
				  from
				       	ȯ�ڻ��̷�	a
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
					s_Error_Msg	 		:= '#19. Seps. ��(ȯ�ڻ��̷�) failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;		
							
			end;
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #20-1. [M170824-1] MAP ������� SBP/DBP ������ ��ȸ									*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
			       		nvl(regexp_substr(a.BLDPRESS, '[^/]+', 1, 1), 999)
			       	 ,	nvl(regexp_substr(a.BLDPRESS, '[^/]+', 1, 2), 999)
			  	  into
			  	  		i_Sbp_Erinf
			  	  	 ,	i_Dbp_Erinf
				  from
				       	��������������	a
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
		  	/* #20-2. [M170824-1] BP �������� ���� MAP ���										*/
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
		  	/* #21. [M170824-1] Lactate 1st �ǽýð� 												*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select  /* Lactic Acid (serum Lactate) E/R ������ ���� ���� */
						min(a.EXECDATE)
				  into	
				  		d_Lactic_1st_Time
	              from
	              		�˻�ó���̷�	a
	             where
	                    a.PATNO    	= in_Patno
	               and  a.MEDDATE  	= in_Meddate
	               and	a.PATSECT	= 'E'
	               and	a.ORDCD		= 'BM3850'						
	               and 	a.EXECDATE	=	(	
	               							select
	               									min(x.EXECDATE)
	               							  from
	               							  		�˻�ó���̷�	x
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
		  	/* #22. [M170824-1] Lactate 2nd �ǽýð� 												*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	if	(trim(d_Lactic_1st_Time) is not null)	then
		  	
			  	begin 
					select  /* Lactic Acid (serum Lactate) E/R ������ ���� ������ 2nd f/u �ǽýð� */
							min(a.EXECDATE)
					  into	
					  		d_Lactic_2nd_Time
		              from
		              		�˻�ó���̷�	a
		             where
		                    a.PATNO    	= in_Patno
		               and  a.MEDDATE  	= in_Meddate
		               and	a.PATSECT	= 'E'
		               and	a.ORDCD		= 'BM3850'						
		               and 	a.EXECDATE	=	(	
		               							select
		               									min(x.EXECDATE)
		               							  from
		               							  		�˻�ó���̷�	x
		               							 where
		               							 		x.PATNO		= a.PATNO
		               							   and	x.MEDDATE	= a.MEDDATE
		               							   and	x.ORDCD		= a.ORDCD
		               							   and	x.EXECDATE	> d_Lactic_1st_Time		/* E/R ������ ���� �������� 2nd f/u */
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
				  
			/* E/R ������ ���� Lactate acid �����̷� ������, 2nd f/u�� null�� ���� */
			else 
			
				d_Lactic_2nd_Time	:= to_date(null);			
			
			end if;
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #23. [M170824-1] �Կ��� ����� ����(NEDIS ����)					  					*/
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select  						
		                decode(c.MEDRSLT,	'6','���'
		                                ,	'7','���'
		                                ,	decode(c.TRANS,	'1','����'
		                                    	          ,	'2','����'
		                                        	      ,	'3','����'
		                                            	  ,	decode(c.DSCHTYPE,	'1','�������'
		                                                                 	 ,	'2','�������'
		                                                                 	 ,	'3','Ż��'
		                                                                 	 ,	'��Ÿ')
		                                        )
		                       )
		           into
		           		s_Dsch_State 
		           from
		           		�Կ������̷� 	a,
		              	���ȯ�����ܰ��� 	c
		          where
		                a.PATNO		= in_Patno 
		            and	a.ADMDATE	= in_Meddate
		            and	a.DSCHDATE	is not null
		            and c.PATNO 	= a.PATNO
		            and c.DSCHDATE 	= a.DSCHDATE
		            and exists 	(select 
		            					1
		                           from 
		                           		��������������	x
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
					s_Error_Msg	 		:= '#23. ����û��� failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  				

	  		
	  		/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #24. [M170915-1] SOFA Score �� ���� �����(�̸�) 									*/	  					  	
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	fn_username_select(max(a.EDITID))
				  into
				  		s_Score_RgtNm
				  from
				       	�����׸񱸼�������	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSSC'
				   and	a.SETCODE	= 'EC08'			/* SOFA Score �հ� 2���̻� ���� */
				   and	a.ITEMVAL	is not null			/* [M171023-1] CPG 2�ܰ� ������ ���� �ʼ����� �߰� */
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_Score_RgtNm 		:= null;							
			   	
				when others then	     
				
					s_Score_RgtNm 		:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#24. SOFA Score ��������� Failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  
			
			
	  		/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #25. [M171019-1] Sepsis ����ó�� (�⺻/�˻�) �������� (Y/N)							*/	  					  	
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
						  		�⺻ó���̷�	a
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
						  		�˻�ó���̷�	a
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
					s_Error_Msg	 		:= '#25. ����ó�� ���� Failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  	
			
			
			/*--------------------------------------------------------------------------------------*/	    		  
		  	/* #26. [M171023-2] Infection �� ���� �����(�̸�) 									*/	  					  	
		  	/*--------------------------------------------------------------------------------------*/			  		  				  	
		  	begin 
				select
				       	fn_username_select(max(a.EDITID))
				  into
				  		s_Infection_RgtNm
				  from
				       	�����׸񱸼�������	a
				 where
				       	a.PATNO   	= in_Patno
				   and 	a.RGTDATE 	= in_Meddate
				   and 	a.SETDATE 	= in_Medtime
				   and	a.SETTYPE	= 'ERSIF'
				   and	a.ITEMVAL	is not null			/* [M171023-1] CPG 1�ܰ� ������ ���� �ʼ����� �߰� */
				   and	a.DELDATE	is null;
				       
			exception
			
				when no_data_found then
	
					s_Infection_RgtNm 	:= null;							
			   	
				when others then	     
				
					s_Infection_RgtNm 	:= null;							
					s_Error_Yn	 		:= 'Y';														
					s_Error_Msg	 		:= '#26. Infection ��������� Failed [' || ' ' || to_char(sqlcode) + '] ' || sqlerrm;					
							
			end;  			
	  	
	  	end if;	/* #3. E/R Sepsis CPG ������ qSOFA - Infection - ����ó�� - SOFA Score Check ���� 	*/
  	
  	end if;	/* #1-2. ���� ��ȿ�ϸ� ����ؼ� E/R Sepsis CPG ��� ������ Check ����		*/
  	
  	          
  	
  	
  	
  	/*------------------------------------------------------------------------------------------------------------------------------*/	    		  
    /* #9-1. ���� Token ���� Value ����																								*/
  	/*------------------------------------------------------------------------------------------------------------------------------*/
  	
    /* #9-1-1. ��ü CPG ��� �󼼳��� Token ��ȯ : ���� Token Ȯ��� �� ���� (�������� ���� ����: ��ū ���� max-size asciz3h)	*/
  	if	in_Jobtype	=	'ALL_TOKEN'		then	    		  
	             
		if	s_System_Open_Yn = 'Y'	then
		
	  		s_Rtn_Token	:= 	s_ER_Target_Yn 										|| '|' ||			/* 1st Token  - E/R Sepsis CPG �����󿩺�									*/
							to_char(nvl(i_Conscious_Cnt, 0))  					|| '|' ||			/* 2nd Token  - qSOFA #1 - �ǽĻ��� �Ǽ� (Alert : 0, �� �� : 1)				*/
							to_char(nvl(i_SBP_Below100_Cnt, 0))					|| '|' ||			/* 3rd Token  - qSOFA #2 - SBP <= 100 �Ǽ� 									*/
							to_char(nvl(i_RR_Above22_Cnt, 0))					|| '|' ||			/* 4th Token  - qSOFA #3 - RR  >= 20  �Ǽ� 									*/
							s_qSOFA_Yn											|| '|' ||			/* 5th Token  - qSOFA Ȱ��ȭ(+) ����(����)���� 								*/
							to_char(d_SOFA_Time, 'yyyymmddhh24mi')				|| '|' ||			/* 6th Token  - qSOFA Ȱ��ȭ(+) ����ð� (��������������.SOFATIME)				*/	  					  
							s_Infection_Yn			 							|| '|' ||			/* 7th Token  - Infection ��� ���� (�����׸񱸼�������.SETTYPE = ERSIF)				*/
							s_SOFA_Score_Above2									|| '|' ||			/* 8th Token  - SOFA Score 2�� �̻� ���� (Y/N)								*/
							s_SOFA_Score_State									|| '|' ||			/* 9th Token  - SOFA Score �������(����Ϸ�: C, �ӽ�����: T, ������: X) ����	*/ 		
							s_Exm_Token											|| '|' ||			/* 10th Token - Sepsis ����ó�� ��� ��� String	  					  	*/
							s_PaO2_Result										|| '|' ||	  		/* 11th Token - PaO2 (ABGA) ������ ù �˻���								*/
							s_Cr_Result											|| '|' || 			/* 12th Token - Creatinine (Cr) ������ ù �˻���							*/
							s_PLT_Result										|| '|' ||			/* 13th Token - Platelet (PLT) ������ ù �˻���							*/
							s_TBil_Result										|| '|' ||			/* 14th Token - Bilirubin, Total (T.bil) ������ ù �˻���    				*/
							s_Exm_Blood											|| '|' ||			/* 15th Token - Blood Cx. �ǽ��̷� 						    				*/
							s_Exm_Urine											|| '|' ||			/* 16th Token - Urine Cx. �ǽ��̷� 						    				*/							
							s_Exm_Sputum										|| '|' ||			/* 17th Token - Sputum Cx. �ǽ��̷� 					    				*/																												                                             
							to_char(i_Lactate_Cnt)								|| '|' ||			/* 18th Token - Lactate f/u Ƚ�� 											*/
							to_char(i_FstAnti_Diff_Medtime)						|| '|' ||		  	/* 19th Token - ���� �׻��� �����ð� - E/R �����Ͻ� gap (��: 1, 2.23, ...)  */
							s_ER_Dsch_Rslt										|| '|' ||		  	/* 20th Token - ����ȯ������������ ��ǰ��                                 */
							s_Dsch_State										|| '|' ||		  	/* 21th Token - ��������(EMR) ����� ����                                 */
							s_Sepsis_Yn											|| '|' ||			/* 22th Token - Sepsis �̷� (Y: ���, N: ����, null: ���ۼ�) ����           */								
							s_Score_EvalTime									|| '|' ||			/* 23th Token - SOFA Score ���Ͻ�	(yyyy-mm-dd hh24:mi)		            */
							s_Seps_Diag_Yn										|| '|' ||			/* 24th Token - Sepsis ��(A41.9) �������		            				*/								 																				 					
							to_char(i_MAP_Result)								|| '|' ||			/* 25th Token - MAP ����� [M170824-1] 									*/
							to_char(d_Lactic_1st_Time, 'yyyy-mm-dd hh24:mi')	|| '|' ||			/* 26th Token - Lactate 1st �ǽýð� [M170824-1]							*/
							to_char(d_Lactic_2nd_Time, 'yyyy-mm-dd hh24:mi')	|| '|' ||			/* 27th Token - Lactate 2nd �ǽýð� [M170824-1]							*/
	  					  	s_Dsch_State										|| '|' ||			/* 28th Token - NEDIS ����� ���� (md_nedis_l1 > ġ����(����) ����) [M170824-1] */
	  					  	s_Score_RgtNm										|| '|' ||			/* 29th Token - CPG 2�ܰ� SOFA Score �� ���� �����(�̸�) [M170915-1]		*/	  					  	
	  					  	s_Bundle_Yn											|| '|' ||			/* 30th Token - Sepsis ����ó�� (�⺻/�˻�) �������� (Y/N)	[M171019-1]		*/
	  						s_Infection_RgtNm;														/* 31th Token - CPG 1�ܰ�(Infection) �� ���� �����(�̸�) [M171023-2] 	*/	  					  
		else
		
			s_Rtn_Token := '';
			
		end if;					
  	   

            
    /* #9-1-2. ����ȯ������������ ����(md_erinf_i3)��, qSOFA Ȱ��ȭ ��󿩺� ��ȯ */                                       
	elsif	in_Jobtype	=	'qSOFA_ON'	then
	                 
		/* ���� qSOFA Ȱ��ȭ �ð� ���������� ���, qSOFA Ȱ��ȭ ����üũ ���(s_qSOFA_Yn) ��ȯ */
		if	trim(d_SOFA_Time)	is null		then
				
			s_Rtn_Token		:=	s_qSOFA_Yn;		
			                       
		/* ���� qSOFA Ȱ��ȭ �ð� �������� ���, CPG ���ƴ�(N) */
		else
		
			s_Rtn_Token     := 'N';
		
		end if;   
		
    /* #9-1-3. CPG 2�ܰ�: SOFA Score �򰡽� E/R ������ �׸� ù �˻��� (4��) Token ���� 	*/
    /* [M170824-1] SOFA Score �򰡽� MAP �ڵ���� ��� ���� �߰� 				 			*/
	elsif	in_Jobtype	=	'EXM_RESULT'	then	
	                                               
		s_Rtn_Token	:= 	s_PaO2_Result										|| '|' ||	  		/* 1st Token - PaO2 (ABGA) ������ ù �˻���								*/
						s_Cr_Result											|| '|' || 			/* 2nd Token - Creatinine (Cr) ������ ù �˻���							*/
						s_PLT_Result										|| '|' ||			/* 3rd Token - Platelet (PLT) ������ ù �˻���							*/
						s_TBil_Result 										|| '|' ||			/* 4th Token - Bilirubin, Total (T.bil) ������ ù �˻���    				*/
						to_char(i_MAP_Result);													/* 5th Token - ������ ù(����) MAP ����� [M170824-1]						*/						
		
	end if;
		

	/*------------------------------------------------------------------------------*/	    		  
    /* #9-Y. üũ �ܰ躰 ���� �߻��� Logging ���� 									*/
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
    /* #9-Z. ���� value ��ȯ															*/
  	/*----------------------------------------------------------------------------------*/
    return(s_Rtn_Token);    
    
end;

/